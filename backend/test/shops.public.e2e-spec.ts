// test/shops.public.e2e-spec.ts
//
// Public végpontok teljes E2E lefedése.
//
// Fedett végpontok:
//   - GET /shops              (alapértelmezett + paginálás)
//   - GET /shops/nearby       (happy path + validáció)
//   - GET /shops/:id          (happy path + 404 + 400 invalid UUID)
//
// Ami SZÁNDÉKOSAN nincs itt:
//   - 429 rate limit teszt — külön spec fájlba kerül a Throttler
//     in-memory állapota miatt (külön app instance kell hozzá).

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

  beforeAll(async () => {
    // A controller findAll-ja minden hívásra console.log-ol — teszt-zaj
    // elnyomás suite szinten. Egyszer beállítjuk, egyszer visszaállítjuk.
    jest.spyOn(console, 'log').mockImplementation(() => undefined);

    const bootstrapped = await bootstrapTestApp();
    app = bootstrapped.app;
    pgClient = bootstrapped.pgClient;
    close = bootstrapped.close;
  });

  afterAll(async () => {
    await close();
    jest.restoreAllMocks();
  });

  // Minden teszt friss DB állapottal indul: 6 fixture-bolt.
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
      // A controller default LIMIT-je 500, a fixture-ek száma 6 → mind belefér.
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
  // GET /shops/nearby — közeli boltok
  // ===============================================================
  describe('GET /shops/nearby', () => {
    it('200-zal és Budapest közeli boltokat ad vissza Hősök tere koordinátáira', async () => {
      // Arrange — Hősök tere koordinátái, 5 km-es sugár
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 47.5147, long: 19.0779, radius: 5000 });

      // Assert
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      // Csak budapesti boltokat várunk ekkora sugárral
      response.body.forEach((shop: { city: string }) => {
        expect(shop.city).toBe('Budapest');
      });
    });

    it('200-zal és üres tömbbel tér vissza, ha a sugáron belül nincs bolt', async () => {
      // Arrange — Atlanti-óceán közepe, 1 km-es sugár → semmi
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 0, long: -30, radius: 1000 });

      // Assert
      expect(response.status).toBe(200);
      expect(response.body).toEqual([]);
    });

    it('400-at ad, ha hiányzik a lat paraméter', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ long: 19.0779 });

      // Assert
      expect(response.status).toBe(400);
    });

    it('400-at ad, ha hiányzik a long paraméter', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 47.5147 });

      // Assert
      expect(response.status).toBe(400);
    });

    it('400-at ad, ha lat nem szám', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 'not-a-number', long: 19.0779 });

      // Assert
      expect(response.status).toBe(400);
    });

    it('400-at ad, ha lat tartományon kívül van (>90)', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 91, long: 19.0779 });

      // Assert
      expect(response.status).toBe(400);
    });

    it('400-at ad, ha radius meghaladja a MAX_RADIUS_METERS-t (50000)', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/shops/nearby')
        .query({ lat: 47.5147, long: 19.0779, radius: 100000 });

      // Assert
      expect(response.status).toBe(400);
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

    it('400-at ad érvénytelen UUID formátumra', async () => {
      // Arrange — ParseUUIDPipe a controlleren ezt elutasítja
      // Act
      const response = await request(app.getHttpServer()).get(
        '/shops/not-a-uuid',
      );

      // Assert
      expect(response.status).toBe(400);
    });
  });
});