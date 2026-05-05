// test/helpers/fixtures.ts
//
// Rögzített ("fixture") adathalmaz az integrációs tesztekhez.
//
// Minden integrációs teszt EZT a hat boltot fogja használni kezdőállapotként.
// A bolt-objektumok fix UUID-kkel és ismert magyar (illetve szándékosan
// választott edge-case) koordinátákkal vannak felvértezve, hogy a tesztek:
//   - reprodukálhatóak legyenek (ugyanaz az adat, ugyanaz a viselkedés),
//   - olvasáskor öndokumentálók legyenek (név szerinti hivatkozás),
//   - és lefedjenek határeseteket (pólus-közeli pont, dátumvonal mellett).

import { Client } from 'pg';

// ---------------------------------------------------------------
// TÍPUSOK
// ---------------------------------------------------------------
//
// A fixture egyetlen bolt rekordot ír le — pontosan annyi mezővel,
// amennyi a tobacco_shops táblába kell. A `location` mezőt nem itt
// tároljuk (az PostGIS geography), hanem a seed függvény generálja
// a lat/long párból ST_MakePoint-tal.

export type ShopFixture = {
  id: string;
  name: string;
  address: string;
  city: string;
  lat: number;
  long: number;
  openingHours: Record<string, string> | null;
};

// ---------------------------------------------------------------
// FIX UUID-K
// ---------------------------------------------------------------
//
// A "00000000-0000-4000-8000-..." minta egy érvényes UUID v4 prefix
// (a 4-es a verzió, a 8-as a variant nibble). A maradék 12 karakter
// szabadon választott — itt egyszerű sorszámozást használunk, hogy
// a teszt-output emberi szemmel is olvasható legyen.

const FIX_UUID = (suffix: string) =>
  `00000000-0000-4000-8000-${suffix.padStart(12, '0')}`;

// ---------------------------------------------------------------
// A FIXTURE OBJEKTUM
// ---------------------------------------------------------------
//
// Az `as const` arra szolgál, hogy a TypeScript a literál típusokat
// őrizze meg ("Budapest" string nem szélesedik ki `string`-re).
// Ez a teszt-asszertekben hasznos, mert a `toBe(...)` szigorúbban
// ellenőriz.

export const SHOP_FIXTURES = {
  // --- Budapest belváros (Hősök tere közelében) ---
  budapestHeroesSquare: {
    id: FIX_UUID('000000000001'),
    name: 'Trafik Hősök tere',
    address: 'Hősök tere 1.',
    city: 'Budapest',
    lat: 47.5147,
    long: 19.0779,
    openingHours: { mon: '09:00-18:00' },
  },

  // --- Budapest belváros (Deák tér), ~3 km az előzőtől ---
  budapestDeakSquare: {
    id: FIX_UUID('000000000002'),
    name: 'Trafik Deák tér',
    address: 'Deák Ferenc tér 5.',
    city: 'Budapest',
    lat: 47.4979,
    long: 19.0547,
    openingHours: { mon: '08:00-20:00', tue: '08:00-20:00' },
  },

  // --- Vác, ~30 km Budapesttől északra ---
  vac: {
    id: FIX_UUID('000000000003'),
    name: 'Trafik Vác',
    address: 'Március 15. tér 10.',
    city: 'Vác',
    lat: 47.7757,
    long: 19.1318,
    openingHours: null,
  },

  // --- Debrecen, ~190 km Budapesttől keletre ---
  debrecen: {
    id: FIX_UUID('000000000004'),
    name: 'Trafik Debrecen',
    address: 'Piac utca 20.',
    city: 'Debrecen',
    lat: 47.5547,
    long: 21.6273,
    openingHours: { mon: '07:00-19:00' },
  },

  // --- Pólus-közeli szintetikus pont (Magyarországon kívül) ---
  // Cél: a findNearby matematikája pólus-közeli koordinátán is működjön.
  // Ez NEM valós bolt — a "Szintetikus" előtag jelzi, hogy edge-case adat.
  syntheticPolar: {
    id: FIX_UUID('000000000005'),
    name: 'Szintetikus pólus-közeli pont',
    address: 'N/A',
    city: 'N/A',
    lat: 89.5,
    long: 0.0,
    openingHours: null,
  },

  // --- Dátumvonal-közeli szintetikus pont ---
  // Cél: long ~180 közelében ne legyen aritmetikai hiba (pl. ha valaki
  // korábban naiv "long-distance" képlettel számolt volna, ez kibukna).
  syntheticDateline: {
    id: FIX_UUID('000000000006'),
    name: 'Szintetikus dátumvonal-közeli pont',
    address: 'N/A',
    city: 'N/A',
    lat: 0.0,
    long: 179.9,
    openingHours: null,
  },
} as const satisfies Record<string, ShopFixture>;

// ---------------------------------------------------------------
// SEGÉDFÜGGVÉNY: a fixture-objektumot tömbbé konvertálja
// ---------------------------------------------------------------
//
// Sok helyen tömbként kezeljük (pl. seed beszúrás). A `Object.values`
// pont ezt csinálja — a típust kifejezetten ShopFixture[]-re cast-oljuk,
// hogy a TypeScript ne `any`-vé szélesítse ki.

export const ALL_SHOPS: ShopFixture[] = Object.values(
  SHOP_FIXTURES,
) as ShopFixture[];

// ---------------------------------------------------------------
// TRUNCATE — a tobacco_shops tábla teljes ürítése
// ---------------------------------------------------------------
//
// A TRUNCATE különbsége a DELETE-hez képest:
//   - O(1) sebesség (nem soronként megy végig),
//   - vacuum-munkát nem hagy maga után,
//   - a RESTART IDENTITY a szekvenciákat is reset-eli (nálunk UUID,
//     de jó gyakorlat odaírni).
//
// A CASCADE itt nem kell, mert nincs FK más táblából a tobacco_shops-ra.

export async function truncateShops(client: Client): Promise<void> {
  await client.query(`TRUNCATE TABLE tobacco_shops RESTART IDENTITY`);
}

// ---------------------------------------------------------------
// SEED — a megadott boltokat beszúrja PostGIS-szel
// ---------------------------------------------------------------
//
// Ugyanazt az SQL-mintát használja, mint a ShopsService.create():
//   ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography
//
// FONTOS koordináta-sorrend: ST_MakePoint(LONG, LAT) — előbb hosszúság,
// utána szélesség. Ez egy klasszikus bug-forrás PostGIS-szel, és ezért
// is hasznos integrációs tesztben validálni.
//
// A pg driver a $1, $2... paraméter-placeholdereket használja
// (Prisma-tól eltérő szintaxis, de ugyanaz az ötlet: SQL injection
// védelem és típuskezelés).

export async function seedShops(
  client: Client,
  shops: ShopFixture[] = ALL_SHOPS,
): Promise<void> {
  for (const shop of shops) {
    await client.query(
      `
      INSERT INTO tobacco_shops
        (id, name, address, city, opening_hours, location, updated_at)
      VALUES
        (
          $1,
          $2,
          $3,
          $4,
          $5::jsonb,
          ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
          NOW()
        )
      `,
      [
        shop.id,
        shop.name,
        shop.address,
        shop.city,
        // A pg driver objektumot natívan nem tud JSONB-be írni,
        // ezért stringify-olunk; a ::jsonb cast a SQL oldalán
        // konvertál vissza.
        shop.openingHours ? JSON.stringify(shop.openingHours) : null,
        shop.long, // ST_MakePoint első argumentuma a hosszúság
        shop.lat,  // második a szélesség
      ],
    );
  }
}