-- CreateExtension
CREATE EXTENSION IF NOT EXISTS postgis;

-- CreateTable
CREATE TABLE "tobacco_shops" (
    "id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "address" VARCHAR(255) NOT NULL,
    "city" VARCHAR(100) NOT NULL,
    "opening_hours" JSONB,
    "location" geography(Point, 4326),
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tobacco_shops_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "shop_location_idx" ON "tobacco_shops" USING GIST ("location");
