import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
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
  findAll() {
    return this.shopsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.shopsService.findOne(+id);
  }
}
