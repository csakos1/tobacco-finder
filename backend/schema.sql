-- Engedélyezzük a PostGIS bővítményt a térképes számításokhoz
CREATE EXTENSION IF NOT EXISTS postgis;

-- Létrehozzuk a boltok tábláját
CREATE TABLE tobacco_shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Egyedi, véletlenszerű azonosító
    name VARCHAR(255) NOT NULL,                    -- A bolt neve
    address VARCHAR(255) NOT NULL,                 -- Teljes cím
    city VARCHAR(100) NOT NULL,                    -- Város (a gyors szűréshez)
    
    -- A nyitvatartást JSON formátumban tároljuk, mert így rugalmasan kezelhetjük
    -- pl.: { "monday": { "open": "08:00", "close": "20:00" }, ... }
    opening_hours JSONB,

    -- Ez a profi rész: Földrajzi pontként tároljuk a helyet (GPS)
    location GEOGRAPHY(POINT, 4326),
    
    updated_at TIMESTAMP DEFAULT NOW()             -- Mikor frissült utoljára az adat
);

-- Létrehozunk egy indexet a térképhez, hogy villámgyors legyen a keresés
CREATE INDEX shop_location_idx ON tobacco_shops USING GIST (location);