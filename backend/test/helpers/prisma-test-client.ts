// test/helpers/prisma-test-client.ts
//
// Factory függvények integrációs tesztekhez:
//   - getTestDatabaseUrl()   → kiolvassa a globalSetup által beállított URI-t
//   - createPgClient()       → nyers pg Client (TRUNCATE / SEED műveletekhez)
//   - createPrismaService()  → valódi PrismaService a NestJS DI-hoz
//
// Mind a kettő ugyanarra a DB-re mutat, csak más absztrakciós szinten.

import { Client } from 'pg';
import { PrismaService } from '../../src/prisma/prisma.service';

// ---------------------------------------------------------------
// ENV VAR NÉV
// ---------------------------------------------------------------
//
// A globalSetup ezt a kulcsot fogja beállítani. Külön konstansban
// tartjuk, hogy egy helyen tudjuk módosítani, ha valaha kéne.
// (TEST_ prefix, hogy ne ütközzön a helyi .env-ben lévő DATABASE_URL-lel.)

export const TEST_DB_URL_ENV = 'TEST_DATABASE_URL';

// ---------------------------------------------------------------
// getTestDatabaseUrl
// ---------------------------------------------------------------
//
// Ha az env nincs beállítva, a teszt nem tud futni — ilyenkor azonnal
// dobjunk értelmes hibát, ne később egy obskúr "ECONNREFUSED" formájában.

export function getTestDatabaseUrl(): string {
  const url = process.env[TEST_DB_URL_ENV];

  if (!url) {
    throw new Error(
      `[teszt-helper] A ${TEST_DB_URL_ENV} environment változó nincs beállítva. ` +
        `Ezt a globalSetup feladata megtenni — futtasd a teszteket a ` +
        `\`npm run test:e2e\` parancson keresztül, ne közvetlenül.`,
    );
  }

  return url;
}

// ---------------------------------------------------------------
// createPgClient
// ---------------------------------------------------------------
//
// Egy friss, csatlakoztatott pg Client-et ad vissza. A hívó felelőssége
// a `client.end()` az afterAll-ban — különben Jest lóg a futás végén
// (open handle leak).

export async function createPgClient(): Promise<Client> {
  const client = new Client({ connectionString: getTestDatabaseUrl() });
  await client.connect();
  return client;
}

// ---------------------------------------------------------------
// createPrismaService
// ---------------------------------------------------------------
//
// A PrismaService a teszt-DB-re mutató DATABASE_URL-lel példányosul.
// Trükk: a Prisma a process.env.DATABASE_URL-t olvassa konstrukciókor,
// ezért a hívás ELŐTT átállítjuk az env változót a teszt URI-ra.
//
// A NestJS lifecycle hook (onModuleInit) explicit hívása helyett itt
// rögtön $connect-elünk — a Test.createTestingModule sem hívja meg
// automatikusan az onModuleInit-et, csak a NestApplication.init()
// futtatja.

export async function createPrismaService(): Promise<PrismaService> {
  // A Prisma a saját DATABASE_URL env-jét olvassa — a teszt-URI-ra
  // állítjuk, mielőtt példányosítanánk.
  process.env.DATABASE_URL = getTestDatabaseUrl();

  const prisma = new PrismaService();
  await prisma.$connect();
  return prisma;
}