// test/shops.rate-limit.e2e-spec.ts
//
// Rate limit (HTTP 429) E2E teszt.
//
// A ThrottlerModule (lásd src/app.module.ts) globálisan él, és minden
// publikus végpontot véd: 100 kérés / 60 mp / IP. A protected route-ok
// @SkipThrottle()-lel ki vannak véve — őket NEM teszteljük itt, mert
// a 429 nem fog rajtuk soha megjelenni.
//
// FONTOS — miért külön spec fájl:
// A throttler állapota in-memory, és az app instance memóriájához van
// kötve. Ha ugyanabban a suite-ban más public tesztet futtatnánk
// utána, már részben felhasznált bucket-tel indulna. Külön fájl =
// külön app instance = friss számláló.
//
// Ez a spec NEM seedeli a DB-t — a GET /shops üres tömbbel is rendben
// 200-zal tér vissza, nekünk csak a státuszkódok érdekesek.

import { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { bootstrapTestApp } from './helpers/app-bootstrap';

describe('Shops — Rate Limit (E2E)', () => {
  let app: INestApplication;
  let close: () => Promise<void>;

  beforeAll(async () => {
    // A controller findAll-ja minden hívásra console.log-ol — ez a
    // spec 100+ findAll-t küld, így kifejezetten szükség van rá.
    jest.spyOn(console, 'log').mockImplementation(() => undefined);

    const bootstrapped = await bootstrapTestApp();
    app = bootstrapped.app;
    close = bootstrapped.close;
  });

  afterAll(async () => {
    await close();
    jest.restoreAllMocks();
  });

  // ===============================================================
  // 100 kérés enged + 101. már 429
  // ===============================================================
  it(
    'engedi az első 100 GET /shops kérést és 429-et ad a 101.-re',
    async () => {
      // Arrange — a limit a ThrottlerModule.forRoot-ban: 100 / 60 mp / IP
      const LIMIT = 100;

      // Act — 100 darab szekvenciális kérés. A párhuzamosítást
      // tudatosan kerüljük: a számláló-növekedések így determinisztikusak.
      const statuses: number[] = [];
      for (let i = 0; i < LIMIT; i++) {
        const response = await request(app.getHttpServer()).get('/shops');
        statuses.push(response.status);
      }

      // A 101. kérés a túllépés
      const overLimit = await request(app.getHttpServer()).get('/shops');

      // Assert — array-szintű egyenlőség, hogy hiba esetén a Jest
      // pontosan mutassa, melyik index hibázott
      expect(statuses).toEqual(new Array(LIMIT).fill(200));
      expect(overLimit.status).toBe(429);
    },
    30_000, // 30s timeout — 101 HTTP roundtrip bőven belefér
  );
});