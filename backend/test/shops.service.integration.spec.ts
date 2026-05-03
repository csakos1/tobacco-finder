// test/shops.service.integration.spec.ts
//
// FÁZIS 3 — INTEGRÁCIÓS TESZTEK a ShopsService-hez, valódi PostGIS-szel.
//
// Lefedi:
//   - sanity check (DB, seed, service oda-vissza),
//   - findNearby (ST_DWithin, ORDER BY ST_Distance, LIMIT, edge case-ek),
//   - findAll paginálás (LIMIT/OFFSET),
//   - findOne (létezik / nem létezik),
//   - create round-trip (beszúrás + visszaolvasás minden mezővel),
//   - update (mező-frissítés + COALESCE koordináta-megőrzés),
//   - remove (törlés ellenőrzése).

import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { Client } from 'pg';

import { ShopsService } from '../src/shops/shops.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { CreateShopDto } from '../src/shops/dto/create-shop.dto';

import {
  createPgClient,
  createPrismaService,
} from './helpers/prisma-test-client';
import {
  SHOP_FIXTURES,
  seedShops,
  truncateShops,
} from './helpers/fixtures';

// ---------------------------------------------------------------
// SEGÉDTÍPUSOK
// ---------------------------------------------------------------

type ShopRow = { id: string };

// A findOne és findAll által visszaadott sorok teljes alakja a service-ből.
// (A service raw SQL-t hív, az eredmény typed-en `any` — itt szűkítjük.)
type FullShopRow = {
  id: string;
  name: string;
  address: string;
  city: string;
  lat: number;
  long: number;
  openingHours: Record<string, string> | null;
  updatedAt: Date;
};

describe('ShopsService — integráció (PostGIS)', () => {
  let pgClient: Client;
  let prismaService: PrismaService;
  let shopsService: ShopsService;

  beforeAll(async () => {
    pgClient = await createPgClient();
    prismaService = await createPrismaService();

    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        ShopsService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    shopsService = moduleRef.get<ShopsService>(ShopsService);
  });

  afterAll(async () => {
    await prismaService?.$disconnect();
    await pgClient?.end();
  });

  beforeEach(async () => {
    await truncateShops(pgClient);
    await seedShops(pgClient);
  });

  // ===============================================================
  // SANITY CHECK
  // ===============================================================
  describe('sanity check', () => {
    it('a tobacco_shops tábla létezik és a seed sikeresen lefutott', async () => {
      const result = await pgClient.query<{ count: string }>(
        `SELECT COUNT(*)::text AS count FROM tobacco_shops`,
      );
      expect(Number(result.rows[0].count)).toBe(6);
    });

    it('a ShopsService a valódi DB-ből ki tudja olvasni a fixture-boltokat', async () => {
      const shops = await shopsService.findAll(500, 0);
      expect(shops).toHaveLength(6);

      const shopIds = (shops as ShopRow[]).map((s) => s.id);
      expect(shopIds).toContain(SHOP_FIXTURES.debrecen.id);
    });
  });

  // ===============================================================
  // findNearby — a core PostGIS metódus
  // ===============================================================
  describe('findNearby', () => {
    const HEROES_LAT = SHOP_FIXTURES.budapestHeroesSquare.lat;
    const HEROES_LONG = SHOP_FIXTURES.budapestHeroesSquare.long;

    it('üres tömböt ad vissza, ha nincs egyetlen bolt sem a DB-ben', async () => {
      await truncateShops(pgClient);

      const result = await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        50_000,
      );

      expect(result).toEqual([]);
    });

    it('1 km-es sugárban csak a Hősök tere boltot adja vissza', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        1_000,
      )) as ShopRow[];

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
    });

    it('5 km-es sugárban mindkét budapesti boltot visszaadja, távolsági sorrendben', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        5_000,
      )) as ShopRow[];

      expect(result).toHaveLength(2);
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
      expect(result[1].id).toBe(SHOP_FIXTURES.budapestDeakSquare.id);
    });

    it('50 km-es sugárban Vácot is visszaadja a két budapesti mellett', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        50_000,
      )) as ShopRow[];

      expect(result).toHaveLength(3);

      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id,
        SHOP_FIXTURES.budapestDeakSquare.id,
        SHOP_FIXTURES.vac.id,
      ]);
    });

    it('250 km-es sugárban Debrecent is visszaadja, mind a négy magyar boltot távolsági sorrendben', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        250_000,
      )) as ShopRow[];

      expect(result).toHaveLength(4);

      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id,
        SHOP_FIXTURES.budapestDeakSquare.id,
        SHOP_FIXTURES.vac.id,
        SHOP_FIXTURES.debrecen.id,
      ]);
    });

    it('a LIMIT a legközelebbi N boltot adja vissza, nem akármelyik N-et', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        250_000,
        2,
      )) as ShopRow[];

      expect(result).toHaveLength(2);
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
      expect(result[1].id).toBe(SHOP_FIXTURES.budapestDeakSquare.id);
    });

    it('pólus-közeli pontból induló keresés nem dob hibát és csak a szintetikus pólus-pontot adja vissza', async () => {
      const result = (await shopsService.findNearby(
        SHOP_FIXTURES.syntheticPolar.lat,
        SHOP_FIXTURES.syntheticPolar.long,
        100_000,
      )) as ShopRow[];

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.syntheticPolar.id);
    });

    it('dátumvonal mellett (long ~180) a keresés helyesen találja meg a szintetikus pontot', async () => {
      const result = (await shopsService.findNearby(
        SHOP_FIXTURES.syntheticDateline.lat,
        SHOP_FIXTURES.syntheticDateline.long,
        100_000,
      )) as ShopRow[];

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.syntheticDateline.id);
    });

    it('használja a default radius (20000 m) értéket, ha nincs explicit megadva', async () => {
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
      )) as ShopRow[];

      expect(result).toHaveLength(2);
      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id,
        SHOP_FIXTURES.budapestDeakSquare.id,
      ]);
    });
  });

  // ===============================================================
  // findAll — paginálás (LIMIT / OFFSET)
  // ===============================================================
  describe('findAll', () => {
    it('LIMIT=2, OFFSET=0 → pontosan 2 boltot ad vissza', async () => {
      const result = (await shopsService.findAll(2, 0)) as ShopRow[];
      expect(result).toHaveLength(2);
    });

    it('LIMIT=2, OFFSET=4 → a 6-os adatból 2-t ad vissza (5. és 6. rekord)', async () => {
      const firstPage = (await shopsService.findAll(2, 0)) as ShopRow[];
      const secondPage = (await shopsService.findAll(2, 2)) as ShopRow[];
      const thirdPage = (await shopsService.findAll(2, 4)) as ShopRow[];

      // Mind a három oldal pontosan 2 elem.
      expect(firstPage).toHaveLength(2);
      expect(secondPage).toHaveLength(2);
      expect(thirdPage).toHaveLength(2);

      // Az oldalak közötti id-k diszjunktak — egyetlen rekord se
      // szerepelhet két oldalon. Ez bizonyítja, hogy az OFFSET helyesen
      // léptet, nem újrakezdi az olvasást.
      const allPagedIds = [
        ...firstPage.map((r) => r.id),
        ...secondPage.map((r) => r.id),
        ...thirdPage.map((r) => r.id),
      ];
      const uniqueIds = new Set(allPagedIds);
      expect(uniqueIds.size).toBe(6);
    });

    it('OFFSET nagyobb mint a rekordok száma → üres tömb', async () => {
      const result = (await shopsService.findAll(10, 100)) as ShopRow[];
      expect(result).toEqual([]);
    });
  });

  // ===============================================================
  // findOne
  // ===============================================================
  describe('findOne', () => {
    it('visszaadja a boltot id alapján, ha létezik', async () => {
      const result = (await shopsService.findOne(
        SHOP_FIXTURES.budapestDeakSquare.id,
      )) as FullShopRow;

      expect(result.id).toBe(SHOP_FIXTURES.budapestDeakSquare.id);
      expect(result.name).toBe(SHOP_FIXTURES.budapestDeakSquare.name);
      expect(result.city).toBe(SHOP_FIXTURES.budapestDeakSquare.city);
    });

    it('NotFoundException-t dob, ha az id nem szerepel a DB-ben', async () => {
      const nonexistentId = '00000000-0000-4000-8000-999999999999';

      await expect(shopsService.findOne(nonexistentId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ===============================================================
  // create — round-trip teszt
  // ===============================================================
  describe('create', () => {
    it('beszúr egy új boltot és a findOne-nal visszaolvasva minden mező egyezik', async () => {
      // Arrange
      const newShop: CreateShopDto = {
        name: 'Új Trafik Szeged',
        address: 'Tisza Lajos krt. 100.',
        city: 'Szeged',
        lat: 46.2530,
        long: 20.1414,
        openingHours: { mon: '08:00-19:00', sun: 'zárva' },
      };

      // Act — INSERT
      await shopsService.create(newShop);

      // Az új bolt id-jét nem ismerjük előre (a service generálja UUID-vel).
      // A szegedi név alapján találjuk meg a friss rekordot.
      const inserted = await pgClient.query<{ id: string }>(
        `SELECT id FROM tobacco_shops WHERE name = $1`,
        [newShop.name],
      );
      expect(inserted.rows).toHaveLength(1);
      const newId = inserted.rows[0].id;

      // Act — round-trip findOne
      const fetched = (await shopsService.findOne(newId)) as FullShopRow;

      // Assert — minden átadott mező pontosan egyezik a visszaolvasott rekorddal
      expect(fetched.name).toBe(newShop.name);
      expect(fetched.address).toBe(newShop.address);
      expect(fetched.city).toBe(newShop.city);
      expect(fetched.openingHours).toEqual(newShop.openingHours);

      // A koordinátáknál numerikus toleranciát használunk (a PostGIS
      // float8-ot tárol, kerekítés lehet az utolsó tizedeseknél).
      expect(fetched.lat).toBeCloseTo(newShop.lat, 5);
      expect(fetched.long).toBeCloseTo(newShop.long, 5);
    });

    it('beszúr egy boltot openingHours nélkül és null-ként olvassa vissza', async () => {
      // Arrange — opcionális mező hiányzik
      const newShop: CreateShopDto = {
        name: 'Új Trafik openingHours nélkül',
        address: 'Teszt utca 1.',
        city: 'Pécs',
        lat: 46.0727,
        long: 18.2323,
      };

      // Act
      await shopsService.create(newShop);

      const inserted = await pgClient.query<{ id: string }>(
        `SELECT id FROM tobacco_shops WHERE name = $1`,
        [newShop.name],
      );
      const fetched = (await shopsService.findOne(
        inserted.rows[0].id,
      )) as FullShopRow;

      // Assert — null kerül a JSONB-be, nem üres objektum
      expect(fetched.openingHours).toBeNull();
    });
  });

  // ===============================================================
  // update — különös tekintettel a COALESCE koordináta-megőrzésre
  // ===============================================================
  describe('update', () => {
    it('frissíti a megadott mezőket és a findOne-nal visszaolvasva azok egyeznek', async () => {
      // Arrange
      const targetId = SHOP_FIXTURES.budapestDeakSquare.id;

      // Act
      await shopsService.update(targetId, {
        name: 'Trafik Deák tér FRISSÍTVE',
        city: 'Budapest XIII.',
      });

      // Assert
      const updated = (await shopsService.findOne(targetId)) as FullShopRow;
      expect(updated.name).toBe('Trafik Deák tér FRISSÍTVE');
      expect(updated.city).toBe('Budapest XIII.');
    });

    it('koordináta-megőrzés (COALESCE): ha a DTO nem tartalmaz lat/long-ot, a régi geometria változatlan marad', async () => {
      // Arrange
      const targetId = SHOP_FIXTURES.vac.id;
      const originalLat = SHOP_FIXTURES.vac.lat;
      const originalLong = SHOP_FIXTURES.vac.long;

      // Act — csak a nevet módosítjuk, koordinátákat NEM küldünk
      await shopsService.update(targetId, {
        name: 'Trafik Vác — átnevezve',
      });

      // Assert — a koordináták érintetlenek
      const updated = (await shopsService.findOne(targetId)) as FullShopRow;
      expect(updated.name).toBe('Trafik Vác — átnevezve');
      expect(updated.lat).toBeCloseTo(originalLat, 5);
      expect(updated.long).toBeCloseTo(originalLong, 5);
    });

    it('koordináta-felülírás: ha a DTO ad új lat/long-ot, a geometria frissül', async () => {
      // Arrange
      const targetId = SHOP_FIXTURES.vac.id;
      const newLat = 47.0;
      const newLong = 19.5;

      // Act
      await shopsService.update(targetId, {
        lat: newLat,
        long: newLong,
      });

      // Assert
      const updated = (await shopsService.findOne(targetId)) as FullShopRow;
      expect(updated.lat).toBeCloseTo(newLat, 5);
      expect(updated.long).toBeCloseTo(newLong, 5);
    });

    it('NotFoundException-t dob, ha az id nem létezik', async () => {
      const nonexistentId = '00000000-0000-4000-8000-999999999999';

      await expect(
        shopsService.update(nonexistentId, { name: 'Bármi' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ===============================================================
  // remove
  // ===============================================================
  describe('remove', () => {
    it('törli a boltot és a findOne-nal NotFoundException-t kapunk vissza', async () => {
      // Arrange
      const targetId = SHOP_FIXTURES.debrecen.id;

      // Act
      await shopsService.remove(targetId);

      // Assert — a rekord nincs többé a DB-ben
      await expect(shopsService.findOne(targetId)).rejects.toThrow(
        NotFoundException,
      );

      // A többi öt fixture érintetlen maradt — törléses keresztszennyezés-teszt
      const remaining = await pgClient.query<{ count: string }>(
        `SELECT COUNT(*)::text AS count FROM tobacco_shops`,
      );
      expect(Number(remaining.rows[0].count)).toBe(5);
    });

    it('NotFoundException-t dob, ha az id nem létezik', async () => {
      const nonexistentId = '00000000-0000-4000-8000-999999999999';

      await expect(shopsService.remove(nonexistentId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});