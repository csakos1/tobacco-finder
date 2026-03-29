import {
  IsString,
  IsNumber,
  IsNotEmpty,
  IsOptional,
  IsObject,
  MaxLength,
  Min,
  Max,
} from 'class-validator';

export class CreateShopDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  address: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  city: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number; // Szélességi fok

  @IsNumber()
  @Min(-180)
  @Max(180)
  long: number; // Hosszúsági fok

  @IsOptional()
  @IsObject()
  openingHours?: Record<string, unknown>; // Nyitvatartás (JSON, opcionális)
}