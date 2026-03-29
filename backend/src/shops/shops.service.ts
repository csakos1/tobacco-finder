import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShopsService {
  constructor(private prisma: PrismaService) {}

  // Bolt létrehozása
  async create(createShopDto: CreateShopDto) {
    const { name, city, address, lat, long, openingHours } = createShopDto;

    await this.prisma.$executeRaw`
      INSERT INTO "tobacco_shops" (id, name, city, address, opening_hours, location)
      VALUES (
        gen_random_uuid(),
        ${name},
        ${city},
        ${address},
        ${openingHours ? JSON.stringify(openingHours) : null},
        ST_SetSRID(ST_MakePoint(${long}, ${lat}), 4326)
      )
    `;

    return 'Bolt sikeresen hozzáadva!';
  }

  // ---------------------------------------------------------------
  // AZ ÖSSZES BOLT LEKÉRÉSE — PAGINÁLVA
  //
  // Korábban ez a metódus limitálás nélkül adta vissza az összes boltot.
  // 5000+ boltnál ez lassú response-t és felesleges memóriahasználatot
  // okozott volna mind a szerveren, mind a kliensen.
  //
  // A LIMIT/OFFSET megoldás itt elegendő, mert:
  //   - Az adathalmaz statikus (boltok, nem feed/timeline)
  //   - A várható méret kezelhető (<10k rekord)
  //   - A frontend nem lapoz végig — csak biztonsági korlát kell
  //   - A rendezés determinisztikus (city, name) az OFFSET konzisztenciájához
  // ---------------------------------------------------------------
  async findAll(limit: number, offset: number) {
    const shops = await this.prisma.$queryRaw`
      SELECT id, name, address, city, 
      opening_hours as "openingHours", 
      ST_Y(location::geometry) as lat, 
      ST_X(location::geometry) as long 
      FROM "tobacco_shops"
      ORDER BY city, name
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    return shops;
  }

  // Csak a közeli boltok lekérése (lat, long és távolság alapján)
  async findNearby(lat: number, long: number, radiusInMeters: number = 20000) {
    const shops = await this.prisma.$queryRaw`
      SELECT id, name, address, city, 
      opening_hours as "openingHours", 
      ST_Y(location::geometry) as lat, 
      ST_X(location::geometry) as long 
      FROM "tobacco_shops"
      WHERE ST_DWithin(
        location, 
        ST_SetSRID(ST_MakePoint(${long}, ${lat}), 4326), 
        ${radiusInMeters}
      )
    `;
    return shops;
  }

  // Egy bolt lekérése UUID alapján
  async findOne(id: string) {
    const shops = await this.prisma.$queryRaw<
      Array<Record<string, unknown>>
    >`
      SELECT id, name, address, city, 
      opening_hours as "openingHours", 
      ST_Y(location::geometry) as lat, 
      ST_X(location::geometry) as long 
      FROM "tobacco_shops"
      WHERE id = ${id}::uuid
    `;

    if (shops.length === 0) {
      throw new NotFoundException(`A(z) ${id} azonosítójú bolt nem található.`);
    }

    return shops[0];
  }

  // Bolt frissítése UUID alapján
  async update(id: string, updateShopDto: UpdateShopDto) {
    // Először ellenőrizzük, hogy létezik-e a bolt
    const existing = await this.prisma.$queryRaw<
      Array<Record<string, unknown>>
    >`
      SELECT id,
      ST_Y(location::geometry) as lat,
      ST_X(location::geometry) as long
      FROM "tobacco_shops"
      WHERE id = ${id}::uuid
    `;

    if (existing.length === 0) {
      throw new NotFoundException(`A(z) ${id} azonosítójú bolt nem található.`);
    }

    // A meglévő koordináták fallback-ként szolgálnak, ha nem küldtek újakat
    const currentLat = existing[0].lat as number;
    const currentLong = existing[0].long as number;

    const name = updateShopDto.name;
    const city = updateShopDto.city;
    const address = updateShopDto.address;
    const lat = updateShopDto.lat ?? currentLat;
    const long = updateShopDto.long ?? currentLong;
    const openingHours = updateShopDto.openingHours;

    await this.prisma.$executeRaw`
      UPDATE "tobacco_shops"
      SET
        name = COALESCE(${name ?? null}, name),
        city = COALESCE(${city ?? null}, city),
        address = COALESCE(${address ?? null}, address),
        opening_hours = COALESCE(
          ${openingHours !== undefined ? JSON.stringify(openingHours) : null},
          opening_hours
        ),
        location = ST_SetSRID(ST_MakePoint(${long}, ${lat}), 4326)
      WHERE id = ${id}::uuid
    `;

    return this.findOne(id);
  }

  // Bolt törlése UUID alapján
  async remove(id: string) {
    // Először ellenőrizzük, hogy létezik-e a bolt
    const existing = await this.prisma.$queryRaw<
      Array<Record<string, unknown>>
    >`
      SELECT id FROM "tobacco_shops"
      WHERE id = ${id}::uuid
    `;

    if (existing.length === 0) {
      throw new NotFoundException(`A(z) ${id} azonosítójú bolt nem található.`);
    }

    await this.prisma.$executeRaw`
      DELETE FROM "tobacco_shops"
      WHERE id = ${id}::uuid
    `;

    return { message: `A(z) ${id} azonosítójú bolt sikeresen törölve.` };
  }
}