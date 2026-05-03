import { Test, TestingModule } from '@nestjs/testing';

import { ShopsController } from './shops.controller';
import { ShopsService } from './shops.service';
import { CreateShopDto } from './dto/create-shop.dto';
import { UpdateShopDto } from './dto/update-shop.dto';

// ---------------------------------------------------------------
// SHOPSSERVICE MOCK TÍPUS
//
// Csak azokat a metódusokat deklaráljuk, amiket a controller hív.
// ---------------------------------------------------------------
type MockShopsService = {
  create: jest.Mock;
  findAll: jest.Mock;
  findNearby: jest.Mock;
  findOne: jest.Mock;
  update: jest.Mock;
  remove: jest.Mock;
};

// ---------------------------------------------------------------
// MOCK REQUEST HELPER
//
// A findAll endpoint @Req() request: any-t kap és request.socket.remoteAddress-t
// olvas. Mivel a típus 'any', nem kell teljes Express.Request-et mockolni —
// elég egy plain object a kívánt elérési lánccal.
// ---------------------------------------------------------------
const createMockRequest = (ip = '127.0.0.1') => ({
  socket: { remoteAddress: ip },
});

describe('ShopsController', () => {
  let controller: ShopsController;
  let service: MockShopsService;

  // A teszt-zaj elnyomására: a controller egy console.log-ot ír a findAll-ban.
  // A spy minden teszt előtt friss, az afterEach restore visszaállít mindent.
  let logSpy: jest.SpyInstance;

  beforeEach(async () => {
    service = {
      create: jest.fn(),
      findAll: jest.fn(),
      findNearby: jest.fn(),
      findOne: jest.fn(),
      update: jest.fn(),
      remove: jest.fn(),
    };

    logSpy = jest.spyOn(console, 'log').mockImplementation(() => undefined);

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ShopsController],
      providers: [{ provide: ShopsService, useValue: service }],
    }).compile();

    controller = module.get<ShopsController>(ShopsController);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // ===============================================================
  // POST /shops
  // ===============================================================
  describe('create', () => {
    const validDto: CreateShopDto = {
      name: 'Trafik',
      city: 'Budapest',
      address: 'Váci út 1.',
      lat: 47.4979,
      long: 19.0402,
    };

    it('továbbadja a DTO-t a service.create-nek és visszaadja a választ', async () => {
      // Arrange
      service.create.mockResolvedValueOnce('Bolt sikeresen hozzáadva!');

      // Act
      const result = await controller.create(validDto);

      // Assert
      expect(service.create).toHaveBeenCalledTimes(1);
      expect(service.create).toHaveBeenCalledWith(validDto);
      expect(result).toBe('Bolt sikeresen hozzáadva!');
    });
  });

  // ===============================================================
  // PATCH /shops/:id
  // ===============================================================
  describe('update', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';

    it('továbbadja az id-t és a DTO-t a service.update-nak', async () => {
      // Arrange
      const dto: UpdateShopDto = { name: 'Új név' };
      const updated = { id: validId, name: 'Új név' };
      service.update.mockResolvedValueOnce(updated);

      // Act
      const result = await controller.update(validId, dto);

      // Assert
      expect(service.update).toHaveBeenCalledTimes(1);
      expect(service.update).toHaveBeenCalledWith(validId, dto);
      expect(result).toEqual(updated);
    });
  });

  // ===============================================================
  // DELETE /shops/:id
  // ===============================================================
  describe('remove', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';

    it('továbbadja az id-t a service.remove-nak', async () => {
      // Arrange
      const expected = {
        message: `A(z) ${validId} azonosítójú bolt sikeresen törölve.`,
      };
      service.remove.mockResolvedValueOnce(expected);

      // Act
      const result = await controller.remove(validId);

      // Assert
      expect(service.remove).toHaveBeenCalledTimes(1);
      expect(service.remove).toHaveBeenCalledWith(validId);
      expect(result).toEqual(expected);
    });
  });

  // ===============================================================
  // GET /shops/nearby
  // ===============================================================
  describe('findNearby', () => {
    it('a megadott paramétereket továbbadja a service-nek', async () => {
      // Arrange
      service.findNearby.mockResolvedValueOnce([]);

      // Act
      await controller.findNearby(47.4979, 19.0402, 5000, 100);

      // Assert
      expect(service.findNearby).toHaveBeenCalledWith(
        47.4979,
        19.0402,
        5000,
        100,
      );
    });

    it('a default radius-t (20000) használja, ha nem érkezett radius', async () => {
      // Arrange
      service.findNearby.mockResolvedValueOnce([]);

      // Act — a radius paraméter undefined
      await controller.findNearby(47.4979, 19.0402, undefined, 100);

      // Assert
      expect(service.findNearby).toHaveBeenCalledWith(
        47.4979,
        19.0402,
        20000, // DEFAULT_RADIUS_METERS
        100,
      );
    });

    it('a default limitet (200) használja, ha a limit undefined', async () => {
      // Arrange
      service.findNearby.mockResolvedValueOnce([]);

      // Act
      await controller.findNearby(47.4979, 19.0402, 5000, undefined);

      // Assert
      expect(service.findNearby).toHaveBeenCalledWith(
        47.4979,
        19.0402,
        5000,
        200, // NEARBY_DEFAULT_LIMIT
      );
    });

    it('a NEARBY_MAX_LIMIT-re vágja a túl nagy limitet (>500)', async () => {
      // Arrange
      service.findNearby.mockResolvedValueOnce([]);

      // Act — a kliens 9999-et kér
      await controller.findNearby(47.4979, 19.0402, 5000, 9999);

      // Assert — a szerver oldali plafon 500
      expect(service.findNearby).toHaveBeenCalledWith(
        47.4979,
        19.0402,
        5000,
        500,
      );
    });

    it('legalább 1-re emeli a limitet, ha 0 vagy negatív érték érkezik', async () => {
      // Arrange
      service.findNearby.mockResolvedValueOnce([]);

      // Act
      await controller.findNearby(47.4979, 19.0402, 5000, 0);

      // Assert
      expect(service.findNearby).toHaveBeenCalledWith(
        47.4979,
        19.0402,
        5000,
        1,
      );
    });

    it('visszaadja a service válaszát változtatás nélkül', async () => {
      // Arrange
      const shops = [{ id: '1', name: 'Bolt' }];
      service.findNearby.mockResolvedValueOnce(shops);

      // Act
      const result = await controller.findNearby(47.4979, 19.0402, 5000, 100);

      // Assert
      expect(result).toEqual(shops);
    });
  });

  // ===============================================================
  // GET /shops
  // ===============================================================
  describe('findAll', () => {
    it('a megadott limit/offset értékeket továbbadja a service-nek', async () => {
      // Arrange
      service.findAll.mockResolvedValueOnce([]);
      const req = createMockRequest('192.168.1.10');

      // Act
      await controller.findAll(req, 250, 50);

      // Assert
      expect(service.findAll).toHaveBeenCalledWith(250, 50);
    });

    it('a MAX_LIMIT-re vágja a túl nagy limitet (>1000)', async () => {
      // Arrange
      service.findAll.mockResolvedValueOnce([]);

      // Act
      await controller.findAll(createMockRequest(), 5000, 0);

      // Assert
      expect(service.findAll).toHaveBeenCalledWith(1000, 0);
    });

    it('legalább 1-re emeli a limitet, ha 0 vagy negatív érték érkezik', async () => {
      // Arrange
      service.findAll.mockResolvedValueOnce([]);

      // Act
      await controller.findAll(createMockRequest(), -10, 0);

      // Assert
      expect(service.findAll).toHaveBeenCalledWith(1, 0);
    });

    it('0-ra emeli a negatív offsetet', async () => {
      // Arrange
      service.findAll.mockResolvedValueOnce([]);

      // Act
      await controller.findAll(createMockRequest(), 500, -5);

      // Assert
      expect(service.findAll).toHaveBeenCalledWith(500, 0);
    });

    it('logolja a kliens IP címét a request socket-jából', async () => {
      // Arrange
      service.findAll.mockResolvedValueOnce([]);

      // Act
      await controller.findAll(createMockRequest('10.0.0.42'), 500, 0);

      // Assert — a console.log spy elkapta a hívást, és benne van az IP
      expect(logSpy).toHaveBeenCalledTimes(1);
      const logMessage = logSpy.mock.calls[0][0] as string;
      expect(logMessage).toContain('10.0.0.42');
      expect(logMessage).toContain('App megnyitva innen');
    });

    it('visszaadja a service válaszát változtatás nélkül', async () => {
      // Arrange
      const shops = [{ id: '1' }, { id: '2' }];
      service.findAll.mockResolvedValueOnce(shops);

      // Act
      const result = await controller.findAll(createMockRequest(), 500, 0);

      // Assert
      expect(result).toEqual(shops);
    });
  });

  // ===============================================================
  // GET /shops/:id
  // ===============================================================
  describe('findOne', () => {
    const validId = '550e8400-e29b-41d4-a716-446655440000';

    it('továbbadja az id-t a service.findOne-nak', async () => {
      // Arrange
      const shop = { id: validId, name: 'Trafik' };
      service.findOne.mockResolvedValueOnce(shop);

      // Act
      const result = await controller.findOne(validId);

      // Assert
      expect(service.findOne).toHaveBeenCalledWith(validId);
      expect(result).toEqual(shop);
    });
  });
});