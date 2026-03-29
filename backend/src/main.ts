import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Globális validációs pipe — minden bejövő kérést a DTO dekorátorai alapján ellenőriz.
  // - whitelist: a DTO-ban nem definiált mezőket automatikusan kiszűri
  // - forbidNonWhitelisted: ha ismeretlen mező érkezik, 400-as hibát dob
  // - transform: a bejövő plain object-et a DTO class példányává alakítja
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.listen(3000, '0.0.0.0');
}
bootstrap();