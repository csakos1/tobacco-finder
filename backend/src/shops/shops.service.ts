import { Injectable } from '@nestjs/common';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShopsService {
  constructor(private prisma: PrismaService) {}

  // 1. Új bolt létrehozása (PostGIS Raw SQL-lel)
  async create(createShopDto: CreateShopDto) {
    const { name, address, city, lat, long } = createShopDto;

    // Mivel a koordinátákat speciális formátumban kell menteni,
    // itt muszáj "nyers" SQL-t használnunk a Prisma helyett.
    // Fontos: A PostGIS-nél a sorrend (LONGITUDE, LATITUDE)!

    await this.prisma.$executeRaw`
      INSERT INTO "tobacco_shops" ("id", "name", "address", "city", "location", "updated_at")
      VALUES (
        gen_random_uuid(), 
        ${name}, 
        ${address}, 
        ${city}, 
        ST_SetSRID(ST_MakePoint(${long}, ${lat}), 4326), 
        NOW()
      )
    `;

    return { message: 'Bolt sikeresen hozzáadva az adatbázishoz!' };
  }

  // 2. Az összes bolt lekérése
  findAll() {
    return this.prisma.tobaccoShop.findMany();
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
