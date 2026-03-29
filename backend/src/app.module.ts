import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';
import { ShopsModule } from './shops/shops.module';

@Module({
  imports: [
    // ---------------------------------------------------------------
    // RATE LIMITING: Globális kéréslimitálás IP cím alapján.
    //
    // Az alapértelmezett korlát: 100 kérés / 60 másodperc / IP.
    // Ez bőven elég a normál apphasználathoz (térkép pásztázás,
    // lista betöltés), de hatékonyan véd a brute-force és
    // DoS jellegű visszaélések ellen.
    //
    // A ThrottlerGuard az APP_GUARD-on keresztül globálisan aktív —
    // minden végpontra vonatkozik, hacsak az adott handler vagy
    // controller nem kap @SkipThrottle() dekorátort.
    //
    // Túllépés esetén a szerver 429 Too Many Requests választ küld.
    // ---------------------------------------------------------------
    ThrottlerModule.forRoot({
      throttlers: [
        {
          name: 'default',
          ttl: 60000, // Időablak: 60 másodperc (milliszekundumban)
          limit: 100, // Maximális kérésszám az időablakon belül
        },
      ],
    }),
    ShopsModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    PrismaService,
    // Globális guard regisztráció — minden route-ra érvényes
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}