import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // ITT A VÁLTOZÁS: Hozzáadtuk a '0.0.0.0'-t
  await app.listen(3000, '0.0.0.0');
}
bootstrap();
