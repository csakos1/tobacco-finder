// test/postgis-container.smoke.e2e-spec.ts

import { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { Client } from 'pg';
import { startPostgisContainer } from './helpers/postgis-test-container';

// A Jest alapértelmezett timeout-ja 5 másodperc, de az ELSŐ futáskor
// a Docker letölti a postgis/postgis:15-3.3 image-et (~600 MB) — ez
// percekig is eltarthat a netedtől függően. Második futástól már
// gyors (image cache).
jest.setTimeout(120_000);

describe('PostGIS Test Container — smoke teszt', () => {
  let container: StartedPostgreSqlContainer;
  let client: Client;

  // A `beforeAll` egyszer fut le a teljes describe blokk előtt — a
  // konténerindítás drága, nem akarjuk minden tesztre újraindítani.
  // (Ha tesztenként független DB állapot kellene, akkor `beforeEach`
  // lenne, de a smoke tesztünk read-only.)
  beforeAll(async () => {
    container = await startPostgisContainer();
    client = new Client({ connectionString: container.getConnectionUri() });
    await client.connect();
  });

  // Cleanup: bezárjuk a kapcsolatot és leállítjuk a konténert.
  // A ?. operátor véd attól, hogy ha a beforeAll félbeszakadt,
  // ne próbáljunk meg null-on metódust hívni.
  afterAll(async () => {
    await client?.end();
    await container?.stop();
  });

  it('elérhető a Postgres és aktív a PostGIS kiterjesztés', async () => {
    const result = await client.query<{ version: string }>(
      `SELECT PostGIS_Version() AS version`,
    );

    expect(result.rows).toHaveLength(1);
    // Egy érvényes verzió string pl. "3.3 USE_GEOS=1 USE_PROJ=1 ..."
    expect(result.rows[0].version).toMatch(/^\d+\.\d+/);
  });

  it('helyesen számolja két magyar pont közötti távolságot', async () => {
    // Budapest (Hősök tere) és Debrecen (Nagyerdő) közötti
    // nagykörös távolság — a valós érték ~190 km.
    const result = await client.query<{ distanceM: string }>(`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(19.0779, 47.5147), 4326)::geography,
        ST_SetSRID(ST_MakePoint(21.6273, 47.5547), 4326)::geography
      ) AS "distanceM"
    `);

    // A pg driver a numeric típust string-ként adja vissza — explicit
    // konvertálunk, mielőtt összehasonlítanánk.
    const distanceKm = Number(result.rows[0].distanceM) / 1000;

    expect(distanceKm).toBeGreaterThan(180);
    expect(distanceKm).toBeLessThan(200);
  });
});