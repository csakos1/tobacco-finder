// test/helpers/postgis-test-container.ts

import {
  PostgreSqlContainer,
  StartedPostgreSqlContainer,
} from '@testcontainers/postgresql';

// A production stackünkkel megegyező image — ugyanaz a PostGIS verzió
// fut a tesztekben, mint a Linode VPS-en. Ez kulcsfontosságú: ha a
// teszt egy adott PostGIS verzión zöld, akkor a production-ben is
// azon a verzión fog futni.
const POSTGIS_IMAGE = 'postgis/postgis:15-3.3';

/**
 * Elindít egy friss PostGIS konténert a tesztekhez.
 *
 * A `@testcontainers/postgresql` automatikusan kezeli:
 *   - random portot oszt ki (nem ütközik más szervizzel)
 *   - megvárja, amíg a Postgres elfogadja a kapcsolatokat
 *   - egyedi adatbázis nevet, usert, jelszót generál
 *
 * A visszaadott konténer példányon hívható:
 *   - container.getConnectionUri() → 'postgresql://user:pass@host:port/db'
 *   - container.stop() → leállítja és törli a konténert
 *
 * FONTOS: A hívó fél felelőssége a `stop()` meghívása az `afterAll`-ban,
 * különben a Docker konténer ott marad a háttérben.
 */
export async function startPostgisContainer(): Promise<StartedPostgreSqlContainer> {
  return new PostgreSqlContainer(POSTGIS_IMAGE).start();
}