import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  Req,
  Query, // 1. MÓDOSÍTÁS: Ez kellett a paraméterek olvasásához
} from '@nestjs/common';

import { ShopsService } from './shops.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

@Controller('shops')
export class ShopsController {
  constructor(private readonly shopsService: ShopsService) {}

  // --- VÉDETT VÉGPONTOK (Csak kulccsal működnek) ---

  @Post()
  @UseGuards(ApiKeyGuard)
  create(@Body() createShopDto: CreateShopDto) {
    return this.shopsService.create(createShopDto);
  }

  @Patch(':id')
  @UseGuards(ApiKeyGuard)
  update(@Param('id') id: string, @Body() updateShopDto: UpdateShopDto) {
    return this.shopsService.update(+id, updateShopDto);
  }

  @Delete(':id')
  @UseGuards(ApiKeyGuard)
  remove(@Param('id') id: string) {
    return this.shopsService.remove(+id);
  }

  // --- PUBLIKUS VÉGPONTOK (Bárki láthatja) ---

  // 2. MÓDOSÍTÁS: Itt az új közeli kereső végpont!
  // FONTOS: Ennek a ':id' ELŐTT kell lennie, különben nem működik!
  @Get('nearby')
  findNearby(
    @Query('lat') lat: string,
    @Query('long') long: string,
    @Query('radius') radius?: string,
  ) {
    return this.shopsService.findNearby(
      parseFloat(lat),
      parseFloat(long),
      radius ? parseFloat(radius) : 20000, // Ha nincs megadva, 20km (20000m) az alap
    );
  }

  @Get()
  findAll(@Req() request: any) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access
    const ip = request.socket.remoteAddress;
    console.log(`[${new Date().toISOString()}] App megnyitva innen: ${ip}`);
    return this.shopsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.shopsService.findOne(+id);
  }
}