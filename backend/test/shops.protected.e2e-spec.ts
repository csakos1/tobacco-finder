// test/shops.protected.e2e-spec.ts
//
// Protected (admin) végpontok teljes E2E lefedése.
//
// Fedett végpontok:
//   - POST /shops             (létrehozás)
//   - PATCH /shops/:id        (frissítés)
//   - DELETE /shops/:id       (törlés)
//
// Minden protected route-on:
//   - 401 hiányzó x-api-key headerre
//   - 401 rossz x-api-key értékre
//   - happy path helyes API kulccsal
//   - 400 érvénytelen body-ra (ahol relevans)
//   - 400 érvénytelen UUID formátumra (ahol relevans)
//   - 404 nem létező UUID-ra (ahol relevans)
//
// FIGYELEM: Ezeken a route-okon @SkipThrottle() van — a 100 req/60s
// rate limit RÁJUK NEM vonatkozik. A 429 teszt csak public végpontokon
// értelmes, és külön spec fájlba kerül.

import { INestApplication } from '@nestjs/common';
import { Client } from 'pg';
import request from 'supertest';

import { bootstrapTestApp, TEST_API_KEY } from './helpers/app-bootstrap';
import {
  SHOP_FIXTURES,
  seedShops,
  truncateShops,
} from './helpers/fixtures';

describe('Shops — Protected végpontok (E2E)', () => {
  let app: INestApplication;
  let pgClient: Client;
  let close: () => Promise<void>;

  beforeAll(async () => {
    // A controller findAll-ja minden hívásra console.log-ol — ezekben
    // a tesztekben nem hívjuk findAll-t, de a console.error-t (ApiKeyGuard
    // hibaág) is el akarjuk nyomni a tiszta kimenet érdekében.
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);

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
  // POST /shops — létrehozás
  // ===============================================================
  describe('POST /shops', () => {
    // Egy stabil, valid body — minden POST teszt ezt módosítja, ha kell.
    const validBody = {
      name: 'Új Trafik Szeged',
      address: 'Tisza Lajos krt. 100.',
      city: 'Szeged',
      lat: 46.253,
      long: 20.1414,
      openingHours: { mon: '08:00-19:00' },
    };

    it('401-et ad, ha hiányzik az x-api-key header', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .post('/shops')
        .send(validBody);

      // Assert
      expect(response.status).toBe(401);
    });

    it('401-et ad, ha rossz x-api-key érkezik', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .post('/shops')
        .set('x-api-key', 'wrong-key-123')
        .send(validBody);

      // Assert
      expect(response.status).toBe(401);
    });

    it('201-et ad és sikeres üzenetet, helyes API kulccsal és valid body-val', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .post('/shops')
        .set('x-api-key', TEST_API_KEY)
        .send(validBody);

      // Assert — a service plain string-et ad vissza, ezért response.text
      expect(response.status).toBe(201);
      expect(response.text).toBe('Bolt sikeresen hozzáadva!');
    });

    it('400-at ad, ha kötelező mező hiányzik a body-ból (name)', async () => {
      // Arrange — name nélkül
      const { name: _omit, ...incompleteBody } = validBody;

      // Act
      const response = await request(app.getHttpServer())
        .post('/shops')
        .set('x-api-key', TEST_API_KEY)
        .send(incompleteBody);

      // Assert
      expect(response.status).toBe(400);
    });

    it('400-at ad, ha lat tartományon kívül van (>90)', async () => {
      // Arrange
      const badBody = { ...validBody, lat: 91 };

      // Act
      const response = await request(app.getHttpServer())
        .post('/shops')
        .set('x-api-key', TEST_API_KEY)
        .send(badBody);

      // Assert
      expect(response.status).toBe(400);
    });
  });

  // ===============================================================
  // PATCH /shops/:id — frissítés
  // ===============================================================
  describe('PATCH /shops/:id', () => {
    // Fix fixture, hogy minden teszt ugyanarra a boltra hivatkozzon.
    const knownShop = SHOP_FIXTURES.budapestHeroesSquare;

    it('401-et ad, ha hiányzik az x-api-key header', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .patch(`/shops/${knownShop.id}`)
        .send({ name: 'Új név' });

      // Assert
      expect(response.status).toBe(401);
    });

    it('200-zal frissít létező boltot és visszaadja az új adatokat', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .patch(`/shops/${knownShop.id}`)
        .set('x-api-key', TEST_API_KEY)
        .send({ name: 'Frissített Név Kft.' });

      // Assert
      expect(response.status).toBe(200);
      expect(response.body.id).toBe(knownShop.id);
      expect(response.body.name).toBe('Frissített Név Kft.');
      // A nem frissített mezők megmaradnak (COALESCE-szal)
      expect(response.body.city).toBe(knownShop.city);
    });

    it('400-at ad érvénytelen UUID formátumra', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .patch('/shops/not-a-uuid')
        .set('x-api-key', TEST_API_KEY)
        .send({ name: 'Új név' });

      // Assert
      expect(response.status).toBe(400);
    });

    it('404-et ad nem létező UUID-ra', async () => {
      // Arrange
      const nonExistentId = '00000000-0000-4000-8000-999999999999';

      // Act
      const response = await request(app.getHttpServer())
        .patch(`/shops/${nonExistentId}`)
        .set('x-api-key', TEST_API_KEY)
        .send({ name: 'Új név' });

      // Assert
      expect(response.status).toBe(404);
    });
  });

  // ===============================================================
  // DELETE /shops/:id — törlés
  // ===============================================================
  describe('DELETE /shops/:id', () => {
    const knownShop = SHOP_FIXTURES.budapestHeroesSquare;

    it('401-et ad, ha hiányzik az x-api-key header', async () => {
      // Act
      const response = await request(app.getHttpServer()).delete(
        `/shops/${knownShop.id}`,
      );

      // Assert
      expect(response.status).toBe(401);
    });

    it('200-zal töröl és visszaadja a sikeres üzenetet az ID-val', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .delete(`/shops/${knownShop.id}`)
        .set('x-api-key', TEST_API_KEY);

      // Assert
      expect(response.status).toBe(200);
      expect(response.body.message).toContain(knownShop.id);
    });

    it('400-at ad érvénytelen UUID formátumra', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .delete('/shops/not-a-uuid')
        .set('x-api-key', TEST_API_KEY);

      // Assert
      expect(response.status).toBe(400);
    });

    it('404-et ad nem létező UUID-ra', async () => {
      // Arrange
      const nonExistentId = '00000000-0000-4000-8000-999999999999';

      // Act
      const response = await request(app.getHttpServer())
        .delete(`/shops/${nonExistentId}`)
        .set('x-api-key', TEST_API_KEY);

      // Assert
      expect(response.status).toBe(404);
    });
  });
});