import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { UpdateShopDto } from './update-shop.dto';

// ---------------------------------------------------------------
// Az UpdateShopDto a CreateShopDto-ból származik PartialType-szal,
// ami minden mezőt opcionálissá tesz. A constraint-ek (IsString,
// MaxLength, Min, Max, stb.) viszont ÉLBEN MARADNAK — ha egy mezőt
// megadunk, ugyanúgy validálódik.
//
// Ezért itt csak a PartialType viselkedését teszteljük; a teljes
// constraint-mátrix lefedése a CreateShopDto spec-ben történik.
// ---------------------------------------------------------------
const validateDto = async (payload: Record<string, unknown>) => {
  const dto = plainToInstance(UpdateShopDto, payload);
  return validate(dto);
};

describe('UpdateShopDto (PartialType)', () => {
  describe('Opcionális viselkedés — minden mező hiányozhat', () => {
    it('elfogad teljesen üres payload-ot', async () => {
      // Arrange + Act
      const errors = await validateDto({});

      // Assert
      expect(errors).toHaveLength(0);
    });

    it('elfogadja, ha csak a name van megadva', async () => {
      // Arrange + Act
      const errors = await validateDto({ name: 'Új név' });

      // Assert
      expect(errors).toHaveLength(0);
    });

    it('elfogadja, ha csak a koordináták vannak megadva', async () => {
      // Arrange + Act
      const errors = await validateDto({ lat: 47.5, long: 19.0 });

      // Assert
      expect(errors).toHaveLength(0);
    });
  });

  describe('Constraint-ek érvényesek, ha a mező megadva van', () => {
    it('elutasítja a 255 karakternél hosszabb name-et', async () => {
      // Arrange
      const errors = await validateDto({ name: 'a'.repeat(256) });

      // Act
      const nameError = errors.find((e) => e.property === 'name');

      // Assert
      expect(nameError).toBeDefined();
      expect(nameError!.constraints).toHaveProperty('maxLength');
    });

    it('elutasítja a 90 feletti lat értéket', async () => {
      // Arrange
      const errors = await validateDto({ lat: 91 });

      // Act
      const latError = errors.find((e) => e.property === 'lat');

      // Assert
      expect(latError).toBeDefined();
      expect(latError!.constraints).toHaveProperty('max');
    });

    it('elutasítja a 100 karakternél hosszabb city-t', async () => {
      // Arrange
      const errors = await validateDto({ city: 'a'.repeat(101) });

      // Act
      const cityError = errors.find((e) => e.property === 'city');

      // Assert
      expect(cityError).toBeDefined();
      expect(cityError!.constraints).toHaveProperty('maxLength');
    });

    it('elfogadja az érvényes részleges frissítést (city + openingHours)', async () => {
      // Arrange + Act
      const errors = await validateDto({
        city: 'Debrecen',
        openingHours: { mon: '08:00-20:00' },
      });

      // Assert
      expect(errors).toHaveLength(0);
    });
  });
});