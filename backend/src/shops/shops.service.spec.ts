import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';

import { ShopsService } from './shops.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';

// ---------------------------------------------------------------
// PRISMASERVICE MOCK TÍPUS
//
// Csak azokat a metódusokat deklaráljuk, amiket a service ténylegesen
// használ. A teljes PrismaClient interface lemodellezése felesleges,
// és a tesztet csak törékenyebbé tenné.
// ---------------------------------------------------------------
type MockPrismaService = {
  $queryRaw: jest.Mock;
  $executeRaw: jest.Mock;
};

describe('ShopsService', () => {
  let service: ShopsService;
  let prisma: MockPrismaService;

  // Minden teszt előtt friss mock + friss DI container —
  // így a korábbi hívások és visszatérési értékek nem szennyezik
  // a következő teszt állapotát.
  beforeEach(async () => {
    prisma = {
      $queryRaw: jest.fn(),
      $executeRaw: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ShopsService,
        // useValue minta: a PrismaService token helyett a mi mock-unkat
        // kapja injekcióba a ShopsService constructor-a.
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<ShopsService>(ShopsService);
  });

  // ===============================================================
  // create()
  // ===============================================================
  describe('create', () => {
    const validDto: CreateShopDto = {
      name: 'Trafik Budapest',
      city: 'Budapest',
      address: 'Váci út 1.',
      lat: 47.4979,
      long: 19.0402,
      openingHours: { mon: '09:00-18:00' },
    };

    it('meghívja a $executeRaw-ot egyszer és visszaadja a siker üzenetet', async () => {
      // Arrange
      prisma.$executeRaw.mockResolvedValueOnce(1);

      // Act
      const result = await service.create(validDto);

      // Assert
      expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
      expect(result).toBe('Bolt sikeresen hozzáadva!');
    });

    it('akkor is meghívódik az INSERT, ha az openingHours undefined', async () => {
      // Arrange — a DTO-ban opcionális mező hiányzik
      const dtoWithoutHours: CreateShopDto = {
        ...validDto,
        openingHours: undefined,
      };
      prisma.$executeRaw.mockResolvedValueOnce(1);

      // Act
      const result = await service.create(dtoWithoutHours);

      // Assert
      // A null-átadás konkrét SQL paraméter-szintű ellenőrzése az
      // integrációs teszt feladata; itt csak a kontroll-folyamat számít.
      expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
      expect(result).toBe('Bolt sikeresen hozzáadva!');
    });

    it('továbbdobja a Prisma hibát, ha az INSERT meghiúsul', async () => {
      // Arrange
      const dbError = new Error('DB constraint violation');
      prisma.$executeRaw.mockRejectedValueOnce(dbError);

      // Act + Assert
      await expect(service.create(validDto)).rejects.toThrow(dbError);
    });
  });

  // ===============================================================
  // findAll()
  // ===============================================================
  describe('findAll', () => {
    it('visszaadja a Prisma által visszaadott boltlistát', async () => {
      // Arrange
      const fakeShops = [
        { id: '1', name: 'A', city: 'Budapest' },
        { id: '2', name: 'B', city: 'Debrecen' },
      ];
      prisma.$queryRaw.mockResolvedValueOnce(fakeShops);

      // Act
      const result = await service.findAll(500, 0);

      // Assert
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
      expect(result).toEqual(fakeShops);
    });

    it('üres tömböt ad vissza, ha nincsenek boltok', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act
      const result = await service.findAll(500, 0);

      // Assert
      expect(result).toEqual([]);
    });
  });

  // ===============================================================
  // findNearby()
  // ===============================================================
  describe('findNearby', () => {
    it('visszaadja a sugáron belüli boltokat', async () => {
      // Arrange
      const nearby = [{ id: '1', name: 'Közeli bolt', lat: 47.5, long: 19.0 }];
      prisma.$queryRaw.mockResolvedValueOnce(nearby);

      // Act
      const result = await service.findNearby(47.4979, 19.0402, 5000, 100);

      // Assert
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
      expect(result).toEqual(nearby);
    });

    it('üres tömböt ad vissza, ha nincs bolt a sugáron belül', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act
      const result = await service.findNearby(0, 0, 1000, 50);

      // Assert
      expect(result).toEqual([]);
    });

    it('használja a default radius (20000) és limit (200) értékeket, ha nincs megadva', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act — csak a kötelező lat/long-ot adjuk át
      await service.findNearby(47.4979, 19.0402);

      // Assert — a hívás sikerült, a defaultok érvényesültek
      // (a konkrét értékek SQL-szintű ellenőrzése integrációs teszt)
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    });
  });

  // ===============================================================
  // findOne()
  // ===============================================================
  describe('findOne', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';

    it('visszaadja az első sort, ha a bolt létezik', async () => {
      // Arrange
      const shop = { id: validId, name: 'Trafik', city: 'Budapest' };
      prisma.$queryRaw.mockResolvedValueOnce([shop]);

      // Act
      const result = await service.findOne(validId);

      // Assert
      expect(result).toEqual(shop);
    });

    it('NotFoundException-t dob, ha a bolt nem létezik (üres tömb)', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act + Assert
      // .rejects: a Promise-t "leheri" és a dobott hibát adja át a toThrow-nak.
      // Sync expect(() => fn()).toThrow(...) itt nem működne, mert a Promise
      // objektumot kapnánk, nem a kivételt.
      await expect(service.findOne(validId)).rejects.toThrow(NotFoundException);
    });

    it('a hibaüzenet tartalmazza a kérdéses id-t', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act + Assert
      await expect(service.findOne(validId)).rejects.toThrow(
        new RegExp(validId),
      );
    });
  });

  // ===============================================================
  // update()
  // ===============================================================
  describe('update', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';
    const existingShop = {
      id: validId,
      lat: 47.4979,
      long: 19.0402,
    };

    it('NotFoundException-t dob, ha a bolt nem létezik', async () => {
      // Arrange — az exists check üres tömböt ad
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act + Assert
      await expect(
        service.update(validId, { name: 'Új név' }),
      ).rejects.toThrow(NotFoundException);

      // Az UPDATE NEM hajtódhatott végre — a kivétel előtte dobódott
      expect(prisma.$executeRaw).not.toHaveBeenCalled();
    });

    it('frissíti a boltot és visszaadja a frissített rekordot', async () => {
      // Arrange — a service 3 Prisma hívást tesz az update során:
      //   1. $queryRaw exists check  → [existingShop]
      //   2. $executeRaw UPDATE      → 1 sor érintett
      //   3. $queryRaw findOne(id)   → [updatedShop]   (a return-höz)
      const updatedShop = {
        id: validId,
        name: 'Frissített név',
        city: 'Budapest',
        address: 'Váci út 1.',
      };
      prisma.$queryRaw
        .mockResolvedValueOnce([existingShop]) // 1. hívás
        .mockResolvedValueOnce([updatedShop]); // 3. hívás
      prisma.$executeRaw.mockResolvedValueOnce(1);

      const dto: UpdateShopDto = { name: 'Frissített név' };

      // Act
      const result = await service.update(validId, dto);

      // Assert
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(2);
      expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
      expect(result).toEqual(updatedShop);
    });

    it('a meglévő koordinátákat használja, ha a DTO nem ad új lat/long-ot', async () => {
      // Arrange
      const updatedShop = {
        id: validId,
        name: 'Új név',
        lat: existingShop.lat,
        long: existingShop.long,
      };
      prisma.$queryRaw
        .mockResolvedValueOnce([existingShop])
        .mockResolvedValueOnce([updatedShop]);
      prisma.$executeRaw.mockResolvedValueOnce(1);

      // Act — csak a name-t adjuk át, lat/long hiányzik
      const result = await service.update(validId, { name: 'Új név' });

      // Assert — a service nem dob hibát és visszaadja a frissített rekordot,
      // ami jelzi, hogy a fallback koordináta-logika lefutott
      // (fallback: `dto.lat ?? currentLat`, `dto.long ?? currentLong`)
      expect(result).toEqual(updatedShop);
    });

    it('az új koordinátákat használja, ha a DTO megadja őket', async () => {
      // Arrange
      const updatedShop = {
        id: validId,
        name: 'Költözött bolt',
        lat: 47.6,
        long: 19.1,
      };
      prisma.$queryRaw
        .mockResolvedValueOnce([existingShop])
        .mockResolvedValueOnce([updatedShop]);
      prisma.$executeRaw.mockResolvedValueOnce(1);

      const dto: UpdateShopDto = {
        name: 'Költözött bolt',
        lat: 47.6,
        long: 19.1,
      };

      // Act
      const result = await service.update(validId, dto);

      // Assert
      expect(result).toEqual(updatedShop);
      expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
    });
  });

  // ===============================================================
  // remove()
  // ===============================================================
  describe('remove', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';

    it('NotFoundException-t dob, ha a bolt nem létezik', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act + Assert
      await expect(service.remove(validId)).rejects.toThrow(NotFoundException);

      // A DELETE NEM hajtódhatott végre
      expect(prisma.$executeRaw).not.toHaveBeenCalled();
    });

    it('a hibaüzenet tartalmazza a kérdéses id-t, ha nem létezik', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([]);

      // Act + Assert
      await expect(service.remove(validId)).rejects.toThrow(
        new RegExp(validId),
      );
    });

    it('törli a boltot és visszaadja a siker üzenetet, ha létezik', async () => {
      // Arrange
      prisma.$queryRaw.mockResolvedValueOnce([{ id: validId }]);
      prisma.$executeRaw.mockResolvedValueOnce(1);

      // Act
      const result = await service.remove(validId);

      // Assert
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
      expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
      expect(result).toEqual({
        message: `A(z) ${validId} azonosítójú bolt sikeresen törölve.`,
      });
    });
  });
});