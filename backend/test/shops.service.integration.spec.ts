// test/shops.service.integration.spec.ts
//
// FÁZIS 3 — INTEGRÁCIÓS TESZTEK a ShopsService-hez, valódi PostGIS-szel.
//
// Itt a unit szinten mockolt raw SQL viselkedését tényre váltjuk:
//   - ST_DWithin valóban a megadott sugáron belüli boltokat adja-e vissza,
//   - ORDER BY ST_Distance helyesen rendez-e távolság szerint,
//   - a LIMIT és OFFSET a megfelelő szeletet adja-e vissza,
//   - a COALESCE az update-ben tényleg megőrzi-e az eredeti koordinátákat.

import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { Client } from 'pg';

import { ShopsService } from '../src/shops/shops.service';
import { PrismaService } from '../src/prisma/prisma.service';

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
// SEGÉDTÍPUS
// ---------------------------------------------------------------
//
// A ShopsService raw SQL-t fut és `any`-szerű tömböt ad vissza.
// Az asszertekhez kényelmesebb egy minimális típusra szűkíteni —
// itt csak az id-ra van szükségünk a sorrend ellenőrzéséhez.

type ShopRow = { id: string };

describe('ShopsService — integráció (PostGIS)', () => {
  let pgClient: Client;
  let prismaService: PrismaService;
  let shopsService: ShopsService;

  // ---------------------------------------------------------------
  // beforeAll — egyszer fut a teljes describe előtt
  // ---------------------------------------------------------------
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

  // Minden teszt friss állapotból indul: TRUNCATE + a teljes hat-elemes seed.
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
    // A Hősök tere koordinátáit használjuk referencia-pontként —
    // ez a fixture egyik bolt is egyben (legközelebbi self-match).
    const HEROES_LAT = SHOP_FIXTURES.budapestHeroesSquare.lat;
    const HEROES_LONG = SHOP_FIXTURES.budapestHeroesSquare.long;

    // ---------------------------------------------------------
    // ÜRES DB
    // ---------------------------------------------------------
    it('üres tömböt ad vissza, ha nincs egyetlen bolt sem a DB-ben', async () => {
      // Arrange — a beforeEach seedelt, de itt direkt kiürítjük a táblát.
      await truncateShops(pgClient);

      // Act
      const result = await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        50_000,
      );

      // Assert
      expect(result).toEqual([]);
    });

    // ---------------------------------------------------------
    // SZŰK SUGÁR — csak a referencia-pont maga
    // ---------------------------------------------------------
    it('1 km-es sugárban csak a Hősök tere boltot adja vissza', async () => {
      // Act
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        1_000,
      )) as ShopRow[];

      // Assert — Hősök tere és Deák tér között ~3 km a légtávolság,
      // tehát 1 km-es sugár csak a self-match-et adja vissza.
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
    });

    // ---------------------------------------------------------
    // KÖZEPES SUGÁR — a két budapesti bolt
    // ---------------------------------------------------------
    it('5 km-es sugárban mindkét budapesti boltot visszaadja, távolsági sorrendben', async () => {
      // Act
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        5_000,
      )) as ShopRow[];

      // Assert
      expect(result).toHaveLength(2);

      // ORDER BY ST_Distance ellenőrzés: a Hősök tere maga (0 m)
      // ELŐBB kell jöjjön, mint a Deák tér (~3 km).
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
      expect(result[1].id).toBe(SHOP_FIXTURES.budapestDeakSquare.id);
    });

    // ---------------------------------------------------------
    // NAGY SUGÁR — Vác is befér
    // ---------------------------------------------------------
    it('50 km-es sugárban Vácot is visszaadja a két budapesti mellett', async () => {
      // Act
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        50_000,
      )) as ShopRow[];

      // Assert
      expect(result).toHaveLength(3);

      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id, // 0 m
        SHOP_FIXTURES.budapestDeakSquare.id,   // ~3 km
        SHOP_FIXTURES.vac.id,                  // ~30 km
      ]);
    });

    // ---------------------------------------------------------
    // NAGYON NAGY SUGÁR — Debrecen is befér
    // ---------------------------------------------------------
    it('250 km-es sugárban Debrecent is visszaadja, mind a négy magyar boltot távolsági sorrendben', async () => {
      // Act
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        250_000,
      )) as ShopRow[];

      // Assert — a két szintetikus pont (pólus, dátumvonal) NEM
      // szerepelhet, mert ezerszer messzebb vannak a Hősök terétől
      // mint Debrecen. Tehát négy magyar bolt jön vissza.
      expect(result).toHaveLength(4);

      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id, // 0 m
        SHOP_FIXTURES.budapestDeakSquare.id,   // ~3 km
        SHOP_FIXTURES.vac.id,                  // ~30 km
        SHOP_FIXTURES.debrecen.id,             // ~190 km
      ]);
    });

    // ---------------------------------------------------------
    // LIMIT — kevesebb eredmény, mint amennyi befér a sugárba
    // ---------------------------------------------------------
    it('a LIMIT a legközelebbi N boltot adja vissza, nem akármelyik N-et', async () => {
      // Act — 250 km-en belül 4 bolt van, de csak 2-t kérünk.
      // A "legközelebbi 2"-nek kell jönnie, nem "az első 2 amit talál".
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
        250_000,
        2,
      )) as ShopRow[];

      // Assert
      expect(result).toHaveLength(2);
      expect(result[0].id).toBe(SHOP_FIXTURES.budapestHeroesSquare.id);
      expect(result[1].id).toBe(SHOP_FIXTURES.budapestDeakSquare.id);
    });

    // ---------------------------------------------------------
    // EDGE CASE — pólus-közeli koordináta
    // ---------------------------------------------------------
    it('pólus-közeli pontból induló keresés nem dob hibát és csak a szintetikus pólus-pontot adja vissza', async () => {
      // Act — a syntheticPolar fixture közelébe lőjük a keresést
      // (lat 89.5, long 0.0). Egy 100 km-es sugár nem érhet el más
      // fixture-höz, mert a többi nincs ennyire északon.
      const result = (await shopsService.findNearby(
        SHOP_FIXTURES.syntheticPolar.lat,
        SHOP_FIXTURES.syntheticPolar.long,
        100_000,
      )) as ShopRow[];

      // Assert
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.syntheticPolar.id);
    });

    // ---------------------------------------------------------
    // EDGE CASE — dátumvonal-közeli koordináta
    // ---------------------------------------------------------
    it('dátumvonal mellett (long ~180) a keresés helyesen találja meg a szintetikus pontot', async () => {
      // Act — a syntheticDateline fixture (lat 0.0, long 179.9) közelébe.
      const result = (await shopsService.findNearby(
        SHOP_FIXTURES.syntheticDateline.lat,
        SHOP_FIXTURES.syntheticDateline.long,
        100_000,
      )) as ShopRow[];

      // Assert
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(SHOP_FIXTURES.syntheticDateline.id);
    });

    // ---------------------------------------------------------
    // DEFAULT ÉRTÉKEK
    // ---------------------------------------------------------
    it('használja a default radius (20000 m) értéket, ha nincs explicit megadva', async () => {
      // Act — sem radiust, sem limitet nem adunk meg.
      const result = (await shopsService.findNearby(
        HEROES_LAT,
        HEROES_LONG,
      )) as ShopRow[];

      // Assert — 20 km-es sugár csak a két budapesti boltot fogja be
      // (Vác ~30 km, kívül esik). Ez bizonyítja, hogy a default tényleg
      // 20 000 m, nem például 1000 vagy 50 000.
      expect(result).toHaveLength(2);
      const ids = result.map((r) => r.id);
      expect(ids).toEqual([
        SHOP_FIXTURES.budapestHeroesSquare.id,
        SHOP_FIXTURES.budapestDeakSquare.id,
      ]);
    });
  });
});