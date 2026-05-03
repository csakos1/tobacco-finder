// test/helpers/global-teardown.ts
//
// A teljes test-run UTÁN egyszer fut le. Egyetlen feladata: leállítani a
// PostGIS konténert, amit a global-setup indított.
//
// Ha ez kimaradna, minden test-run után egy árva Docker konténer maradna
// a háttérben — egy idő után tele lenne velük a rendszer.

import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';

declare global {
  // eslint-disable-next-line no-var
  var __POSTGIS_CONTAINER__: StartedPostgreSqlContainer | undefined;
}

export default async function globalTeardown(): Promise<void> {
  const container = globalThis.__POSTGIS_CONTAINER__;

  if (container) {
    console.log('\n[global-teardown] PostGIS konténer leállítása...');
    await container.stop();
    console.log('[global-teardown] Konténer leállítva.');
  }
}