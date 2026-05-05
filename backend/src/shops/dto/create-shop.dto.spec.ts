import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { CreateShopDto } from './create-shop.dto';

// ---------------------------------------------------------------
// HELPER: érvényes alapadat-objektum, amit a tesztek felülírnak
// egy-egy mezőre koncentrálva. Így nem kell minden tesztben
// minden mezőt felsorolni.
// ---------------------------------------------------------------
const buildValidPayload = () => ({
  name: 'Trafik Budapest',
  address: 'Váci út 1.',
  city: 'Budapest',
  lat: 47.4979,
  long: 19.0402,
  openingHours: { mon: '09:00-18:00' },
});

// ---------------------------------------------------------------
// HELPER: DTO példány építése + validálás egy lépésben.
// A class-validator instance-ot vár, ezért előbb a class-transformer
// plainToInstance hívásával osztálypéldánnyá alakítjuk az input-ot.
// ---------------------------------------------------------------
const validateDto = async (payload: Record<string, unknown>) => {
  const dto = plainToInstance(CreateShopDto, payload);
  return validate(dto);
};

describe('CreateShopDto', () => {
  // ===============================================================
  // ÉRVÉNYES ADATOK — happy path
  // ===============================================================
  describe('Érvényes adatok', () => {
    it('elfogad egy teljes érvényes payload-ot', async () => {
      // Arrange
      const payload = buildValidPayload();

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });

    it('elfogad payload-ot openingHours nélkül (opcionális mező)', async () => {
      // Arrange
      const { openingHours: _omit, ...payload } = buildValidPayload();

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  // ===============================================================
  // name mező
  // ===============================================================
  describe('name validáció', () => {
    it.each([
      ['hiányzik (undefined)', undefined, 'isNotEmpty'],
      ['üres string', '', 'isNotEmpty'],
      ['nem string (number)', 123, 'isString'],
      ['255 karakternél hosszabb', 'a'.repeat(256), 'maxLength'],
    ])('elutasítja, ha %s', async (_label, value, expectedConstraint) => {
      // Arrange
      const payload = { ...buildValidPayload(), name: value };

      // Act
      const errors = await validateDto(payload);
      const nameError = errors.find((e) => e.property === 'name');

      // Assert
      expect(nameError).toBeDefined();
      expect(nameError!.constraints).toHaveProperty(expectedConstraint);
    });

    it('elfogadja a pontosan 255 karakter hosszú nevet (határérték)', async () => {
      // Arrange
      const payload = { ...buildValidPayload(), name: 'a'.repeat(255) };

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  // ===============================================================
  // address mező
  // ===============================================================
  describe('address validáció', () => {
    it.each([
      ['hiányzik', undefined, 'isNotEmpty'],
      ['üres string', '', 'isNotEmpty'],
      ['nem string', 42, 'isString'],
      ['255 karakternél hosszabb', 'a'.repeat(256), 'maxLength'],
    ])('elutasítja, ha %s', async (_label, value, expectedConstraint) => {
      // Arrange
      const payload = { ...buildValidPayload(), address: value };

      // Act
      const errors = await validateDto(payload);
      const addressError = errors.find((e) => e.property === 'address');

      // Assert
      expect(addressError).toBeDefined();
      expect(addressError!.constraints).toHaveProperty(expectedConstraint);
    });
  });

  // ===============================================================
  // city mező — ennek 100 a max length, nem 255
  // ===============================================================
  describe('city validáció', () => {
    it.each([
      ['hiányzik', undefined, 'isNotEmpty'],
      ['üres string', '', 'isNotEmpty'],
      ['nem string', true, 'isString'],
      ['100 karakternél hosszabb', 'a'.repeat(101), 'maxLength'],
    ])('elutasítja, ha %s', async (_label, value, expectedConstraint) => {
      // Arrange
      const payload = { ...buildValidPayload(), city: value };

      // Act
      const errors = await validateDto(payload);
      const cityError = errors.find((e) => e.property === 'city');

      // Assert
      expect(cityError).toBeDefined();
      expect(cityError!.constraints).toHaveProperty(expectedConstraint);
    });

    it('elfogadja a pontosan 100 karakter hosszú város nevet (határérték)', async () => {
      // Arrange
      const payload = { ...buildValidPayload(), city: 'a'.repeat(100) };

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  // ===============================================================
  // lat mező — szélesség, [-90, 90]
  // ===============================================================
  describe('lat validáció', () => {
    it.each([
      ['hiányzik', undefined, 'isNumber'],
      ['nem szám (string)', 'forty-seven', 'isNumber'],
      ['-90 alatt (-90.001)', -90.001, 'min'],
      ['90 felett (90.001)', 90.001, 'max'],
    ])('elutasítja, ha %s', async (_label, value, expectedConstraint) => {
      // Arrange
      const payload = { ...buildValidPayload(), lat: value };

      // Act
      const errors = await validateDto(payload);
      const latError = errors.find((e) => e.property === 'lat');

      // Assert
      expect(latError).toBeDefined();
      expect(latError!.constraints).toHaveProperty(expectedConstraint);
    });

    it.each([
      ['déli pólus', -90],
      ['egyenlítő', 0],
      ['északi pólus', 90],
    ])('elfogadja a határértéket: %s (%s)', async (_label, value) => {
      // Arrange
      const payload = { ...buildValidPayload(), lat: value };

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  // ===============================================================
  // long mező — hosszúság, [-180, 180]
  // ===============================================================
  describe('long validáció', () => {
    it.each([
      ['hiányzik', undefined, 'isNumber'],
      ['nem szám', null, 'isNumber'],
      ['-180 alatt', -180.001, 'min'],
      ['180 felett', 180.001, 'max'],
    ])('elutasítja, ha %s', async (_label, value, expectedConstraint) => {
      // Arrange
      const payload = { ...buildValidPayload(), long: value };

      // Act
      const errors = await validateDto(payload);
      const longError = errors.find((e) => e.property === 'long');

      // Assert
      expect(longError).toBeDefined();
      expect(longError!.constraints).toHaveProperty(expectedConstraint);
    });

    it.each([
      ['nyugati dátumvonal', -180],
      ['greenwichi délkör', 0],
      ['keleti dátumvonal', 180],
    ])('elfogadja a határértéket: %s (%s)', async (_label, value) => {
      // Arrange
      const payload = { ...buildValidPayload(), long: value };

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  // ===============================================================
  // openingHours mező — opcionális, de ha van, objektum kell legyen
  // ===============================================================
  describe('openingHours validáció', () => {
    it('elfogadja, ha hiányzik (opcionális mező)', async () => {
      // Arrange
      const { openingHours: _omit, ...payload } = buildValidPayload();

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });

    it('elfogadja, ha érvényes objektum', async () => {
      // Arrange
      const payload = {
        ...buildValidPayload(),
        openingHours: { mon: '09:00-18:00', tue: '09:00-18:00' },
      };

      // Act
      const errors = await validateDto(payload);

      // Assert
      expect(errors).toHaveLength(0);
    });

    it('elutasítja, ha string érkezik objektum helyett', async () => {
      // Arrange
      const payload = {
        ...buildValidPayload(),
        openingHours: 'monday 9-18',
      };

      // Act
      const errors = await validateDto(payload);
      const ohError = errors.find((e) => e.property === 'openingHours');

      // Assert
      expect(ohError).toBeDefined();
      expect(ohError!.constraints).toHaveProperty('isObject');
    });
  });

  // ===============================================================
  // Több constraint együtt sérül
  // ===============================================================
  describe('Több hiba egyidejűleg', () => {
    it('minden sérült mezőt jelent egyszerre', async () => {
      // Arrange — három mező egyszerre érvénytelen
      const payload = {
        name: '',
        address: 'a'.repeat(300),
        city: 'Budapest',
        lat: 91,
        long: 19.0402,
      };

      // Act
      const errors = await validateDto(payload);
      const errorProperties = errors.map((e) => e.property).sort();

      // Assert
      expect(errorProperties).toEqual(['address', 'lat', 'name']);
    });
  });
});