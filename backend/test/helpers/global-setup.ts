// test/helpers/global-setup.ts
//
// Jest globalSetup hook: a teljes integrációs/e2e suite ELŐTT egyszer fut le.
//
// Mit csinál:
//   1. Elindít egy PostGIS Testcontainert.
//   2. A connection URI-t beírja a process.env-be (TEST_DATABASE_URL),
//      hogy a worker-folyamatok (a tényleges spec fájlok) elérjék.
//   3. Lefuttatja a `prisma migrate deploy` parancsot a friss DB-n —
//      pontosan ugyanaz a parancs, ami production deploy-ban is fut.
//   4. A konténer referenciát egy globális JS objektumon menti, hogy
//      a globalTeardown leállíthassa.
//
// Új fogalmak itt:
//   - globalSetup: Jest config-ban megadott függvény, ami a teljes
//     test-run előtt EGYSZER fut le. NEM ugyanaz, mint a beforeAll
//     (ami spec fájlon belül egyszer fut).
//   - child_process.execFile: külső parancsot futtat (itt: prisma CLI),
//     a kimenetet stdout/stderr-en várja vissza.
//   - global namespace augmentation: a globalThis-re tett
//     "__POSTGIS_CONTAINER__" mező a teardown számára teszi elérhetővé
//     a konténer példányt anélkül, hogy fájlba mentenénk.

import {
  PostgreSqlContainer,
  StartedPostgreSqlContainer,
} from '@testcontainers/postgresql';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';

import { TEST_DB_URL_ENV } from './prisma-test-client';

const execFileAsync = promisify(execFile);

// A docker-compose.yml-lel megegyező image — production-azonos PostGIS verzió.
const POSTGIS_IMAGE = 'postgis/postgis:15-3.3';

// Globális mező a teardown számára. A `var` szándékos — ez teszi a
// globalThis-re tehetővé.
declare global {
  // eslint-disable-next-line no-var
  var __POSTGIS_CONTAINER__: StartedPostgreSqlContainer | undefined;
}

export default async function globalSetup(): Promise<void> {
  console.log('\n[global-setup] PostGIS konténer indítása...');

  // ---------------------------------------------------------------
  // 1. Konténer indítása
  // ---------------------------------------------------------------
  const container = await new PostgreSqlContainer(POSTGIS_IMAGE).start();
  const url = container.getConnectionUri();

  console.log(`[global-setup] Konténer fut: ${url}`);

  // ---------------------------------------------------------------
  // 2. Env változó beállítása a worker folyamatok számára
  // ---------------------------------------------------------------
  //
  // A workerek külön Node-process-ben futnak, de Jest átörökíti a
  // globalSetup által módosított process.env-et. Ezért elég itt
  // beállítani — a spec fájlok ugyanezt fogják látni.

  process.env[TEST_DB_URL_ENV] = url;

  // ---------------------------------------------------------------
  // 3. Prisma migráció lefuttatása a teszt DB-re
  // ---------------------------------------------------------------
  //
  // A `prisma migrate deploy` parancs a `prisma/migrations/` mappában
  // lévő összes migration-t alkalmazza, pontosan ugyanazon az úton,
  // ahogy a production deploy is csinálja. Ez azt jelenti: ha valaki
  // egy elromlott migrationt commit-ol, az integrációs teszt fog elsőként
  // jelezni.
  //
  // A backend mappa abszolút útvonalát számoljuk, hogy a Jest bárhonnan
  // futhasson (Arch + zsh kombináció esetén is konzisztens).

  const backendDir = path.resolve(__dirname, '..', '..');

  console.log('[global-setup] Prisma migrate deploy futtatása...');

  await execFileAsync('npx', ['prisma', 'migrate', 'deploy'], {
    cwd: backendDir,
    env: {
      ...process.env,
      // A Prisma a DATABASE_URL-t olvassa migráláskor, nem a TEST_DATABASE_URL-t.
      // Külön env-objektumot adunk át, ahol a kettő egybeesik.
      DATABASE_URL: url,
    },
  });

  console.log('[global-setup] Migráció kész.');

  // ---------------------------------------------------------------
  // 4. Konténer mentése a teardown számára
  // ---------------------------------------------------------------
  globalThis.__POSTGIS_CONTAINER__ = container;
}