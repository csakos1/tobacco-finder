// test/shops.service.integration.spec.ts
//
// FÁZIS 3 — INTEGRÁCIÓS TESZT, sanity check.
//
// Ez az első integrációs tesztünk. Egyetlen célja: bizonyítani, hogy a
// teljes infrastruktúra működik:
//   - a globalSetup elindította a PostGIS konténert,
//   - a TEST_DATABASE_URL env elérhető,
//   - a `prisma migrate deploy` lefutott (létezik a tobacco_shops tábla),
//   - a fixture helper (truncateShops + seedShops) működik,
//   - a ShopsService a valódi PrismaService-en át tud olvasni a DB-ből.
//
// Ha ez zöld, a többi teszt írása "csak" a viselkedés specifikálása —
// nem kell az infrastruktúrát újra ellenőrizni minden specben.

import { Test, TestingModule } from '@nestjs/testing';
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

describe('ShopsService — integráció (PostGIS)', () => {
  // ---------------------------------------------------------------
  // SUITE-SZINTŰ ÁLLAPOT
  // ---------------------------------------------------------------
  //
  // Egy konténer, egy DB kapcsolat, egy NestJS DI container — mindezt
  // megosztjuk minden tesztben a describe-on belül. Az adatkonzisztenciát
  // a beforeEach hozza vissza (TRUNCATE + SEED).

  let pgClient: Client;
  let prismaService: PrismaService;
  let shopsService: ShopsService;

  // ---------------------------------------------------------------
  // beforeAll — egyszer fut a teljes describe előtt
  // ---------------------------------------------------------------
  beforeAll(async () => {
    // 1. Nyers pg kliens a TRUNCATE/SEED műveletekhez.
    //    (Gyorsabb és egyszerűbb, mint Prisma raw query-vel csinálni.)
    pgClient = await createPgClient();

    // 2. Valódi PrismaService a teszt-DB-re mutatva.
    prismaService = await createPrismaService();

    // 3. NestJS DI container a ShopsService számára, a valódi PrismaService-szel.
    //    Ez a kulcs: ugyanaz a Test.createTestingModule API, mint a unit tesztekben,
    //    csak a `useValue` most nem mock, hanem valódi, csatlakozott PrismaService.
    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        ShopsService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    shopsService = moduleRef.get<ShopsService>(ShopsService);
  });

  // ---------------------------------------------------------------
  // afterAll — egyszer fut a teljes describe után
  // ---------------------------------------------------------------
  //
  // Bezárjuk a kapcsolatokat. Ha kihagynánk, Jest "open handle" warning-ot
  // dobna a futás végén, és a folyamat nem feltétlenül exitel-ne tisztán.
  afterAll(async () => {
    await prismaService?.$disconnect();
    await pgClient?.end();
  });

  // ---------------------------------------------------------------
  // beforeEach — minden teszt előtt friss kezdőállapot
  // ---------------------------------------------------------------
  //
  // TRUNCATE + SEED: a tábla teljesen üres lesz, majd a hat fixture-bolt
  // visszakerül. Így minden teszt ugyanazt látja, függetlenül attól,
  // mit művelt az előző (akár sikertelen) teszt.
  beforeEach(async () => {
    await truncateShops(pgClient);
    await seedShops(pgClient);
  });

  // ===============================================================
  // SANITY TESZTEK
  // ===============================================================
  describe('sanity check', () => {
    it('a tobacco_shops tábla létezik és a seed sikeresen lefutott', async () => {
      // Arrange — a beforeEach már beszúrta a hat fixture-boltot.

      // Act — közvetlen pg-vel számolunk, kihagyva a Prisma absztrakciót,
      // hogy ha a Prisma maga lenne hibás, az is kibukjon.
      const result = await pgClient.query<{ count: string }>(
        `SELECT COUNT(*)::text AS count FROM tobacco_shops`,
      );

      // Assert
      // A pg driver a COUNT(*)-ot stringként adja vissza (numeric típus),
      // ezért explicit konvertálunk.
      expect(Number(result.rows[0].count)).toBe(6);
    });

    it('a ShopsService a valódi DB-ből ki tudja olvasni a fixture-boltokat', async () => {
      // Act — most már a teljes service-réteget használjuk.
      // Ez ugyanaz a metódus, ami production-ben is fut a HTTP réteg alatt.
      const shops = await shopsService.findAll(500, 0);

      // Assert — pontosan a hat seed-rekordot kapjuk vissza.
      expect(shops).toHaveLength(6);

      // A debrecen fixture id-jának szerepelnie kell az eredményben.
      // (Konkrét sorrendet itt NEM asszertálunk — azt majd a findNearby
      // ORDER BY ST_Distance teszt fogja célzottan validálni.)
      const shopIds = (shops as Array<{ id: string }>).map((s) => s.id);
      expect(shopIds).toContain(SHOP_FIXTURES.debrecen.id);
    });
  });
});