import { Injectable } from '@nestjs/common';
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

  // Az összes bolt lekérése (Koordinátákkal és Nyitvatartással)
  async findAll() {
    const shops = await this.prisma.$queryRaw`
      SELECT id, name, address, city, 
      opening_hours as "openingHours", 
      ST_Y(location::geometry) as lat, 
      ST_X(location::geometry) as long 
      FROM "tobacco_shops"
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

  // --- Placeholder végpontok (később implementálandó) ---

  findOne(id: number) {
    return `This action returns a #${id} shop`;
  }

  update(id: number, updateShopDto: UpdateShopDto) {
    return `This action updates a #${id} shop`;
  }

  remove(id: number) {
    return `This action removes a #${id} shop`;
  }
}