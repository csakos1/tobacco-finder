// test/postgis-container.smoke.e2e-spec.ts
//
// Smoke teszt: bizonyítja, hogy a globalSetup által indított PostGIS
// konténer él, az extension aktív, és az ST_Distance helyesen számol
// két ismert magyar koordináta között.
//
// FONTOS — felelősség-megosztás:
// Ez a spec MÁR NEM indít saját konténert. A `globalSetup` egyetlen
// PostGIS konténert indít a teljes E2E suite-ra, és a TEST_DATABASE_URL
// env változón keresztül adja át a connection URI-t. A spec dolga csak
// a kapcsolat felépítése (createPgClient) és a viselkedés ellenőrzése.
// A konténer leállítását a `globalTeardown` intézi.
//
// Korábbi verzióhoz képest:
//   - eltűnt a `startPostgisContainer()` hívás (felesleges második konténer)
//   - eltűnt a `jest.setTimeout(120_000)` (image letöltés a globalSetup-ban van)
//   - eltűnt a `container.stop()` az afterAll-ból (globalTeardown felelős)

import { Client } from 'pg';
import { createPgClient } from './helpers/prisma-test-client';

describe('PostGIS Test Container — smoke teszt', () => {
  let client: Client;

  // A globalSetup már elindította a konténert és lefuttatta a migrációt;
  // itt csak rácsatlakozunk a megosztott URI-ra. Pár tíz millisecundum.
  beforeAll(async () => {
    client = await createPgClient();
  });

  // Cleanup: csak a saját pg kapcsolatot zárjuk. Ha a beforeAll félbeszakadt
  // és a client undefined maradt, a ?. operátor véd a null-on hívástól.
  afterAll(async () => {
    await client?.end();
  });

  it('elérhető a Postgres és aktív a PostGIS kiterjesztés', async () => {
    // Act
    const result = await client.query<{ version: string }>(
      `SELECT PostGIS_Version() AS version`,
    );

    // Assert — érvényes verzió string pl. "3.3 USE_GEOS=1 USE_PROJ=1 ..."
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].version).toMatch(/^\d+\.\d+/);
  });

  it('helyesen számolja két magyar pont közötti távolságot', async () => {
    // Arrange — Budapest (Hősök tere) és Debrecen (Nagyerdő) közötti
    // nagykörös távolság a valós érték szerint ~190 km.

    // Act
    const result = await client.query<{ distanceM: string }>(`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(19.0779, 47.5147), 4326)::geography,
        ST_SetSRID(ST_MakePoint(21.6273, 47.5547), 4326)::geography
      ) AS "distanceM"
    `);

    // A pg driver a numeric típust string-ként adja vissza — explicit
    // konvertálunk Number-re, mielőtt összehasonlítanánk.
    const distanceKm = Number(result.rows[0].distanceM) / 1000;

    // Assert — toleranciát hagyunk, mert a koordináták kerekítettek.
    expect(distanceKm).toBeGreaterThan(180);
    expect(distanceKm).toBeLessThan(200);
  });
});