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
  Query,
  ParseUUIDPipe,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';

import { ShopsService } from './shops.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

// ---------------------------------------------------------------
// LIMITEK: A findAll végpont maximális és alapértelmezett lekérési mérete.
//
// A DEFAULT_LIMIT az a szám, amit a kliens kap, ha nem küld limit paramétert.
// A MAX_LIMIT a szerver által engedett felső korlát — hiába kér valaki 10000-et,
// ennél többet nem kap. Ez véd a túl nagy response-ok ellen.
// ---------------------------------------------------------------
const DEFAULT_LIMIT = 500;
const MAX_LIMIT = 1000;

@Controller('shops')
export class ShopsController {
  constructor(private readonly shopsService: ShopsService) {}

  // --- VÉDETT VÉGPONTOK (Csak API kulccsal működnek) ---

  @Post()
  @UseGuards(ApiKeyGuard)
  create(@Body() createShopDto: CreateShopDto) {
    return this.shopsService.create(createShopDto);
  }

  @Patch(':id')
  @UseGuards(ApiKeyGuard)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateShopDto: UpdateShopDto,
  ) {
    return this.shopsService.update(id, updateShopDto);
  }

  @Delete(':id')
  @UseGuards(ApiKeyGuard)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.shopsService.remove(id);
  }

  // --- PUBLIKUS VÉGPONTOK (Bárki elérheti) ---

  // FONTOS: Ennek a ':id' ELŐTT kell lennie, különben a NestJS
  // a "nearby" stringet route paraméterként próbálná értelmezni.
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
  findAll(
    @Req() request: any,
    @Query('limit', new DefaultValuePipe(DEFAULT_LIMIT), ParseIntPipe)
    limit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe)
    offset: number,
  ) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access
    const ip = request.socket.remoteAddress;
    console.log(`[${new Date().toISOString()}] App megnyitva innen: ${ip}`);

    // Szerver oldali felső korlát — a kliens nem kérhet többet, mint MAX_LIMIT
    const safeLimitValue = Math.min(Math.max(limit, 1), MAX_LIMIT);
    const safeOffsetValue = Math.max(offset, 0);

    return this.shopsService.findAll(safeLimitValue, safeOffsetValue);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.shopsService.findOne(id);
  }
}