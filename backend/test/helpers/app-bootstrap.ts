// test/helpers/app-bootstrap.ts
//
// E2E TESZT BOOTSTRAP — production-paritású NestJS app indítása
//
// Ez a factory egy teljes futó NestJS appot indít (HTTP szerverrel,
// route-okkal, guardokkal, validációval), és mellé egy nyers pg
// klienst ad TRUNCATE/SEED műveletekhez. Több spec is használhatja —
// minden spec saját app instance-t kap a beforeAll-ban.
//
// FONTOS — main.ts paritás:
// A `Test.createTestingModule().compile()` NEM aktiválja automatikusan
// a globális pipe-okat, filtereket és interceptorokat. Itt KÉZZEL
// kell replikálni mindent, amit a `src/main.ts` csinál — különben a
// validációs E2E tesztek hamis zöldet adnának (nincs pipe → nincs
// validáció → minden payload átmegy).
//
// Ami AppModule-ban van wire-elve (pl. ThrottlerGuard APP_GUARD-on
// keresztül), az automatikusan aktív — azzal nem kell foglalkozni itt.

import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Client } from 'pg';

import { AppModule } from '../../src/app.module';
import { createPgClient, getTestDatabaseUrl } from './prisma-test-client';

// ---------------------------------------------------------------
// FIX TESZT API KULCS
//
// Az ApiKeyGuard timing-safe összehasonlítást végez a process.env.API_KEY
// és a kérés `x-api-key` headere között. A kulcsot itt deklaráljuk
// konstansként, hogy a spec-ek importálhassák — így nincs string-duplikáció
// és nem lehet véletlenül elgépelni teszt és app oldalon.
// ---------------------------------------------------------------
export const TEST_API_KEY = 'test-api-key-for-e2e-only';

export interface BootstrappedApp {
  app: INestApplication;
  pgClient: Client;
  apiKey: string;
  close: () => Promise<void>;
}

export async function bootstrapTestApp(): Promise<BootstrappedApp> {
  // 1. Env változók beállítása MIELŐTT a modul betöltődne.
  //    - DATABASE_URL: a Prisma ezt olvassa konstrukciókor
  //    - API_KEY: az ApiKeyGuard ezt olvassa minden hívásnál
  process.env.DATABASE_URL = getTestDatabaseUrl();
  process.env.API_KEY = TEST_API_KEY;

  // 2. Modul compile — ugyanaz az AppModule, ami productionben fut.
  //    A ThrottlerGuard, a controllerek és a PrismaService mind ezen
  //    a modulon keresztül kerülnek be.
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  // 3. Nest app létrehozása — innen lesz HTTP route és middleware réteg.
  const app = moduleRef.createNestApplication();

  // 4. main.ts paritás — pontosan ugyanaz a globális ValidationPipe.
  //    Ha bármit változtatunk a main.ts-ben, ezt is frissíteni kell!
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // 5. App inicializálása — innentől válaszol a getHttpServer() route-okra.
  //    Nem hívunk listen()-t: nem kell valódi port-foglalás, a Supertest
  //    közvetlenül a getHttpServer() http.Server példányát hajtja meg.
  await app.init();

  // 6. Külön pg kliens TRUNCATE/SEED-hez. Az app saját Prisma-ja és
  //    ez a kliens ugyanarra a teszt DB-re mutatnak — nem ütköznek,
  //    csak más absztrakciós szinten dolgoznak ugyanazon a táblán.
  const pgClient = await createPgClient();

  return {
    app,
    pgClient,
    apiKey: TEST_API_KEY,
    close: async () => {
      // Sorrend számít: előbb a kliens-kapcsolatot zárjuk, majd az
      // appot. Ha fordítva csinálnánk, az app close-ja még futhat, és
      // egy kósza pg query miatt megakadna.
      await pgClient.end();
      await app.close();
    },
  };
}