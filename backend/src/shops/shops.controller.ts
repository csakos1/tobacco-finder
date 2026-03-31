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
import { SkipThrottle } from '@nestjs/throttler';

import { ShopsService } from './shops.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';
import { ParseFloatPipe } from '../common/pipes/parse-float.pipe';

// ---------------------------------------------------------------
// LIMITEK: A findAll végpont maximális és alapértelmezett lekérési mérete.
//
// A DEFAULT_LIMIT az a szám, amit a kliens kap, ha nem küld limit paramétert.
// A MAX_LIMIT a szerver által engedett felső korlát — hiába kér valaki 10000-et,
// ennél többet nem kap. Ez véd a túl nagy response-ok ellen.
// ---------------------------------------------------------------
const DEFAULT_LIMIT = 500;
const MAX_LIMIT = 1000;

// ---------------------------------------------------------------
// NEARBY VÉGPONT ALAPÉRTÉKEI
//
// A sugár alapértéke 20 km (20000 méter), maximuma 50 km.
// A 50 km-es korlát véd az indokolatlanul nagy lekérdezések ellen,
// amelyek az egész országot lefednék és túlterhelnék a PostGIS-t.
//
// A NEARBY_DEFAULT_LIMIT az alapértelmezett boltszám, amit a nearby
// végpont visszaad. A NEARBY_MAX_LIMIT a szerver oldali felső korlát —
// ez véd a túl nagy response-ok ellen nagy sugárral történő lekérésnél.
// 200 bolt bőven lefedi a normál használatot (térkép + lista nézet),
// és a kliens memória-limitjével (500) is jól összhangban van.
// ---------------------------------------------------------------
const DEFAULT_RADIUS_METERS = 20000;
const MAX_RADIUS_METERS = 50000;
const NEARBY_DEFAULT_LIMIT = 200;
const NEARBY_MAX_LIMIT = 500;

@Controller('shops')
export class ShopsController {
  constructor(private readonly shopsService: ShopsService) {}

  // --- VÉDETT VÉGPONTOK (Csak API kulccsal működnek) ---
  // A @SkipThrottle() kivonja ezeket a rate limiting alól,
  // mivel az ApiKeyGuard már védi őket — felesleges duplán korlátozni.

  @Post()
  @SkipThrottle()
  @UseGuards(ApiKeyGuard)
  create(@Body() createShopDto: CreateShopDto) {
    return this.shopsService.create(createShopDto);
  }

  @Patch(':id')
  @SkipThrottle()
  @UseGuards(ApiKeyGuard)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateShopDto: UpdateShopDto,
  ) {
    return this.shopsService.update(id, updateShopDto);
  }

  @Delete(':id')
  @SkipThrottle()
  @UseGuards(ApiKeyGuard)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.shopsService.remove(id);
  }

  // --- PUBLIKUS VÉGPONTOK (Bárki elérheti) ---
  // Ezeket a globális ThrottlerGuard védi: 100 kérés / 60 mp / IP.

  // FONTOS: Ennek a ':id' ELŐTT kell lennie, különben a NestJS
  // a "nearby" stringet route paraméterként próbálná értelmezni.
  @Get('nearby')
  findNearby(
    @Query('lat', new ParseFloatPipe({ min: -90, max: 90 }))
    lat: number,
    @Query('long', new ParseFloatPipe({ min: -180, max: 180 }))
    long: number,
    @Query('radius', new ParseFloatPipe({ optional: true, min: 1, max: MAX_RADIUS_METERS }))
    radius?: number,
    @Query('limit', new DefaultValuePipe(NEARBY_DEFAULT_LIMIT), ParseIntPipe)
    limit?: number,
  ) {
    // Szerver oldali felső korlát — a kliens nem kérhet többet, mint NEARBY_MAX_LIMIT
    const safeLimit = Math.min(Math.max(limit ?? NEARBY_DEFAULT_LIMIT, 1), NEARBY_MAX_LIMIT);

    return this.shopsService.findNearby(
      lat,
      long,
      radius ?? DEFAULT_RADIUS_METERS,
      safeLimit,
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