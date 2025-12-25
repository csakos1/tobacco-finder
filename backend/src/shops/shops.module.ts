/* eslint-disable prettier/prettier */
import { Module } from '@nestjs/common';
import { ShopsService } from './shops.service';
import { ShopsController } from './shops.controller';
import { PrismaService } from '../prisma/prisma.service'; // Beimportáljuk a szervizt

@Module({
  controllers: [ShopsController],
  providers: [ShopsService, PrismaService], // Hozzáadjuk a szolgáltatókhoz
})
export class ShopsModule {}