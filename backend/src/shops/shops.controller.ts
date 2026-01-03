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
} from '@nestjs/common';

import { ShopsService } from './shops.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';
import { ApiKeyGuard } from '../auth/api-key.guard'; // Beimportáljuk az őrt

@Controller('shops')
export class ShopsController {
  constructor(private readonly shopsService: ShopsService) {}

  // --- VÉDETT VÉGPONTOK (Csak kulccsal működnek) ---

  @Post()
  @UseGuards(ApiKeyGuard) // Lakat rá
  create(@Body() createShopDto: CreateShopDto) {
    return this.shopsService.create(createShopDto);
  }

  @Patch(':id')
  @UseGuards(ApiKeyGuard) // Lakat rá
  update(@Param('id') id: string, @Body() updateShopDto: UpdateShopDto) {
    return this.shopsService.update(+id, updateShopDto);
  }

  @Delete(':id')
  @UseGuards(ApiKeyGuard) // Lakat rá
  remove(@Param('id') id: string) {
    return this.shopsService.remove(+id);
  }

  // --- PUBLIKUS VÉGPONTOK (Bárki láthatja) ---

  @Get()
  findAll(@Req() request: any) {
    // Itt kérjük be a Request-et
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
