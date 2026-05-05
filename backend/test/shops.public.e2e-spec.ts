// test/shops.public.e2e-spec.ts
//
// Public végpontok E2E tesztjei (kezdő készlet).
// Ez a fájl bizonyítja, hogy az app-bootstrap helyesen indít egy
// NestJS appot, és a teljes HTTP → Controller → Service → DB lánc
// válaszol a fixture-adatokkal.
//
// A KÖVETKEZŐ KÖRÖN bővítjük: 400 validációs hibák, /shops/nearby
// teszt-csokor, a controller pontos viselkedéséhez igazítva.

import { INestApplication } from '@nestjs/common';
import { Client } from 'pg';
import request from 'supertest';

import { bootstrapTestApp } from './helpers/app-bootstrap';
import {
  ALL_SHOPS,
  SHOP_FIXTURES,
  seedShops,
  truncateShops,
} from './helpers/fixtures';

describe('Shops — Public végpontok (E2E)', () => {
  let app: INestApplication;
  let pgClient: Client;
  let close: () => Promise<void>;

  // Az app és a DB kapcsolat egyszer indul a teljes describe blokkra.
  // Az app boot ~500-800 ms — nem akarjuk minden teszt előtt megismételni.
  beforeAll(async () => {
    const bootstrapped = await bootstrapTestApp();
    app = bootstrapped.app;
    pgClient = bootstrapped.pgClient;
    close = bootstrapped.close;
  });

  // Cleanup: a helper által visszaadott close() rendezetten zár mindent.
  afterAll(async () => {
    await close();
  });

  // Minden teszt friss DB állapottal indul: 6 fixture-bolt.
  // Ugyanaz a TRUNCATE+SEED minta, ami az integrációs tesztben már bevált.
  beforeEach(async () => {
    await truncateShops(pgClient);
    await seedShops(pgClient);
  });

  // ===============================================================
  // GET /shops — paginált listázás
  // ===============================================================
  describe('GET /shops', () => {
    it('200-zal válaszol és tömböt ad vissza alapértelmezett hívásra', async () => {
      // Act
      const response = await request(app.getHttpServer()).get('/shops');

      // Assert
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      // A pontos elemszám a backend alap-LIMIT-jétől függ; a fixture-ök
      // száma (6) biztosan kisebb a default LIMIT-nél, így mindet vissza kell adnia.
      expect(response.body.length).toBe(ALL_SHOPS.length);
    });

    it('limit query paraméterrel csak a kért mennyiséget adja vissza', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops')
        .query({ limit: 2, offset: 0 });

      // Assert
      expect(response.status).toBe(200);
      expect(response.body).toHaveLength(2);
    });
  });

  // ===============================================================
  // GET /shops/:id — egy bolt UUID alapján
  // ===============================================================
  describe('GET /shops/:id', () => {
    it('200-zal és a megfelelő bolttal tér vissza létező UUID-ra', async () => {
      // Arrange — fix UUID-s fixture, így determinisztikus a teszt
      const knownShop = SHOP_FIXTURES.budapestHeroesSquare;

      // Act
      const response = await request(app.getHttpServer()).get(
        `/shops/${knownShop.id}`,
      );

      // Assert
      expect(response.status).toBe(200);
      expect(response.body.id).toBe(knownShop.id);
      expect(response.body.name).toBe(knownShop.name);
      expect(response.body.city).toBe(knownShop.city);
    });

    it('404-et ad nem létező UUID-ra', async () => {
      // Arrange — formailag érvényes UUID v4, de nincs ilyen rekord
      const nonExistentId = '00000000-0000-4000-8000-999999999999';

      // Act
      const response = await request(app.getHttpServer()).get(
        `/shops/${nonExistentId}`,
      );

      // Assert
      expect(response.status).toBe(404);
    });
  });
});