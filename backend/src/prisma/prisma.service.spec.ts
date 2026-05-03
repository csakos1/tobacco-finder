import { PrismaService } from './prisma.service';

describe('PrismaService', () => {
  let service: PrismaService;

  beforeEach(() => {
    service = new PrismaService();
  });

  describe('onModuleInit', () => {
    it('csatlakozik az adatbázishoz a modul inicializálásakor', async () => {
      // Arrange
      // A $connect a PrismaClient ősosztály metódusa — közvetlenül spy-oljuk a
      // példányon, hogy a teszt ne nyisson valódi DB kapcsolatot.
      const connectSpy = jest
        .spyOn(service, '$connect')
        .mockResolvedValueOnce(undefined);

      // Act
      await service.onModuleInit();

      // Assert
      expect(connectSpy).toHaveBeenCalledTimes(1);
    });

    it('továbbdobja a hibát, ha a $connect meghiúsul', async () => {
      // Arrange
      const connectError = new Error('A DB nem elérhető');
      jest.spyOn(service, '$connect').mockRejectedValueOnce(connectError);

      // Act + Assert
      await expect(service.onModuleInit()).rejects.toThrow(connectError);
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });
});