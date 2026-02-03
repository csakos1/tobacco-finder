import { Injectable } from '@nestjs/common';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShopsService {
  constructor(private prisma: PrismaService) {}

  // 1. Bolt létrehozása (JAVÍTVA: ID generálással!)
  async create(createShopDto: any) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const { name, city, address, lat, long, openingHours } = createShopDto;

    // VÁLTOZÁS:
    // 1. Beírtuk az 'id'-t az oszlopok közé.
    // 2. Beírtuk a 'gen_random_uuid()'-t az értékek közé.
    await this.prisma.$executeRaw`
      INSERT INTO "tobacco_shops" (id, name, city, address, opening_hours, location)
      VALUES (gen_random_uuid(), ${name}, ${city}, ${address}, ${openingHours}, ST_SetSRID(ST_MakePoint(${long}, ${lat}), 4326))
    `;

    return 'Bolt sikeresen hozzáadva!';
  }

  // 2. Az összes bolt lekérése (Koordinátákkal együtt!)
  // 2. Az összes bolt lekérése (Koordinátákkal és Nyitvatartással)
  async findAll() {
    // FONTOS VÁLTOZÁS:
    // Mivel a schema.prisma-ban @map("opening_hours") van, 
    // az adatbázisban 'opening_hours' a neve.
    // Ezt átnevezzük (AS) "openingHours"-ra, hogy a Frontend értse.

    const shops = await this.prisma.$queryRaw`
      SELECT id, name, address, city, 
      opening_hours as "openingHours", 
      ST_Y(location::geometry) as lat, 
      ST_X(location::geometry) as long 
      FROM "tobacco_shops"
    `;

    return shops;
  }

  // 3. Csak a közeli boltok lekérése (lat, long és távolság alapján)
  async findNearby(lat: number, long: number, radiusInMeters: number = 20000) {
    // ST_DWithin: Megnézi, mi van a körzeten belül.
    // ST_Distance: Opcionális, ha távolság szerint akarod rendezni.
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

  // --- Ezeket a függvényeket egyelőre békén hagyjuk (később töltjük ki) ---

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
