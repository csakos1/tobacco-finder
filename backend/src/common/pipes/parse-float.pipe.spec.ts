import { ArgumentMetadata, BadRequestException } from '@nestjs/common';
import { ParseFloatPipe } from './parse-float.pipe';

// ---------------------------------------------------------------
// HELPER: Minimal ArgumentMetadata mock objektum.
//
// A pipe csak a `metadata.data` mezőt használja a hibaüzenetekben,
// így nem kell a teljes ArgumentMetadata interfészt lemodellezni —
// egy cast elnémítja a TS típusrendszert (a többi mező irreleváns).
// ---------------------------------------------------------------
const createMetadata = (paramName: string): ArgumentMetadata =>
  ({ type: 'query', data: paramName }) as ArgumentMetadata;

describe('ParseFloatPipe', () => {
  // ===============================================================
  // 1. OPCIONÁLIS PARAMÉTER ÁG
  // ===============================================================
  describe('Opcionális paraméterek kezelése', () => {
    it('undefined-ot ad vissza, ha optional=true és az érték undefined', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ optional: true });

      // Act
      const result = pipe.transform(undefined, createMetadata('radius'));

      // Assert
      expect(result).toBeUndefined();
    });

    it('undefined-ot ad vissza, ha optional=true és az érték üres string', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ optional: true });

      // Act
      const result = pipe.transform('', createMetadata('radius'));

      // Assert
      expect(result).toBeUndefined();
    });

    it('feldolgozza az érvényes értéket akkor is, ha optional=true', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ optional: true, min: 0, max: 100 });

      // Act
      const result = pipe.transform('42', createMetadata('radius'));

      // Assert
      expect(result).toBe(42);
    });
  });

  // ===============================================================
  // 2. KÖTELEZŐ PARAMÉTER HIÁNYA
  // ===============================================================
  describe('Kötelező paraméter hiánya', () => {
    it('BadRequestException-t dob, ha a kötelező érték undefined', () => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act + Assert
      // A lambdába csomagolás kell, hogy a Jest a kivételt elkapja —
      // különben a szinkron throw megszakítaná a teszt futását.
      expect(() => pipe.transform(undefined, createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });

    it('BadRequestException-t dob, ha a kötelező érték üres string', () => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act + Assert
      expect(() => pipe.transform('', createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });

    it('a hibaüzenet tartalmazza a paraméter nevét és a "kötelező" szót', () => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act + Assert
      expect(() => pipe.transform(undefined, createMetadata('lat'))).toThrow(
        /lat/,
      );
      expect(() => pipe.transform(undefined, createMetadata('lat'))).toThrow(
        /kötelező/,
      );
    });
  });

  // ===============================================================
  // 3. ÉRVÉNYES SZÁMKONVERZIÓ — Happy path
  // ===============================================================
  describe('Érvényes szám-konverzió', () => {
    // Az it.each() egy paraméterezett teszt: a táblázat minden sorára
    // egyszer lefuttatja az alábbi callback-et, behelyettesítve az
    // %s (string) és %p (pretty-printed) helyőrzőket a teszt nevébe.
    it.each([
      ['egész szám', '42', 42],
      ['tizedes tört', '3.14', 3.14],
      ['negatív szám', '-7.5', -7.5],
      ['nulla', '0', 0],
      ['tudományos jelölés', '1e3', 1000],
      ['vezető nullák', '007', 7],
    ])('helyesen konvertál: %s ("%s" → %p)', (_label, input, expected) => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act
      const result = pipe.transform(input as string, createMetadata('value'));

      // Assert
      expect(result).toBe(expected);
    });
  });

  // ===============================================================
  // 4. ÉRVÉNYTELEN SZÁM-BEMENET (NaN / Infinity)
  // ===============================================================
  describe('Érvénytelen szám-bemenet elutasítása', () => {
    it.each([
      ['nem szám string', 'abc'],
      ['Infinity literál', 'Infinity'],
      ['negatív Infinity', '-Infinity'],
      ['NaN literál', 'NaN'],
    ])('BadRequestException-t dob: %s ("%s")', (_label, input) => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act + Assert
      expect(() => pipe.transform(input, createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });

    it('a hibaüzenet tartalmazza a paraméter nevét és a kapott értéket', () => {
      // Arrange
      const pipe = new ParseFloatPipe();

      // Act + Assert
      expect(() => pipe.transform('abc', createMetadata('lat'))).toThrow(/lat/);
      expect(() => pipe.transform('abc', createMetadata('lat'))).toThrow(/abc/);
    });
  });

  // ===============================================================
  // 5. MIN / MAX TARTOMÁNY-ELLENŐRZÉS
  // ===============================================================
  describe('Tartomány-ellenőrzés — minimum', () => {
    it('elfogadja a min határértéket (inkluzív)', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ min: -90 });

      // Act
      const result = pipe.transform('-90', createMetadata('lat'));

      // Assert
      expect(result).toBe(-90);
    });

    it('elutasítja a min alatti értéket', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ min: -90 });

      // Act + Assert
      expect(() => pipe.transform('-90.001', createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });

    it('a hibaüzenet tartalmazza a min értéket és a kapott értéket', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ min: 0 });

      // Act + Assert
      expect(() => pipe.transform('-5', createMetadata('radius'))).toThrow(
        /nem lehet kisebb/,
      );
      expect(() => pipe.transform('-5', createMetadata('radius'))).toThrow(
        /-5/,
      );
    });
  });

  describe('Tartomány-ellenőrzés — maximum', () => {
    it('elfogadja a max határértéket (inkluzív)', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ max: 90 });

      // Act
      const result = pipe.transform('90', createMetadata('lat'));

      // Assert
      expect(result).toBe(90);
    });

    it('elutasítja a max feletti értéket', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ max: 90 });

      // Act + Assert
      expect(() => pipe.transform('90.001', createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });

    it('a hibaüzenet tartalmazza a max értéket', () => {
      // Arrange
      const pipe = new ParseFloatPipe({ max: 50000 });

      // Act + Assert
      expect(() =>
        pipe.transform('60000', createMetadata('radius')),
      ).toThrow(/50000/);
      expect(() =>
        pipe.transform('60000', createMetadata('radius')),
      ).toThrow(/nem lehet nagyobb/);
    });
  });

  // ===============================================================
  // 6. VALÓS KONFIGURÁCIÓK A findNearby VÉGPONTBÓL
  // ===============================================================
  describe('Latitude tartomány (-90 .. 90) — findNearby valós használat', () => {
    let pipe: ParseFloatPipe;

    beforeEach(() => {
      pipe = new ParseFloatPipe({ min: -90, max: 90 });
    });

    it.each([
      ['déli pólus', '-90', -90],
      ['egyenlítő', '0', 0],
      ['északi pólus', '90', 90],
      ['Budapest szélesség', '47.4979', 47.4979],
    ])('elfogadja a(z) %s értéket ("%s")', (_label, input, expected) => {
      expect(pipe.transform(input as string, createMetadata('lat'))).toBe(
        expected,
      );
    });

    it.each([
      ['déli pólus alatt', '-90.001'],
      ['északi pólus felett', '90.001'],
      ['nagyon kicsi', '-1000'],
      ['nagyon nagy', '1000'],
    ])('elutasítja a(z) %s értéket ("%s")', (_label, input) => {
      expect(() => pipe.transform(input, createMetadata('lat'))).toThrow(
        BadRequestException,
      );
    });
  });

  describe('Longitude tartomány (-180 .. 180) — findNearby valós használat', () => {
    let pipe: ParseFloatPipe;

    beforeEach(() => {
      pipe = new ParseFloatPipe({ min: -180, max: 180 });
    });

    it.each([
      ['nyugati dátumvonal', '-180', -180],
      ['greenwichi délkör', '0', 0],
      ['keleti dátumvonal', '180', 180],
      ['Budapest hosszúság', '19.0402', 19.0402],
    ])('elfogadja a(z) %s értéket ("%s")', (_label, input, expected) => {
      expect(pipe.transform(input as string, createMetadata('long'))).toBe(
        expected,
      );
    });

    it.each([
      ['nyugati dátumvonalon túl', '-180.001'],
      ['keleti dátumvonalon túl', '180.001'],
    ])('elutasítja a(z) %s értéket ("%s")', (_label, input) => {
      expect(() => pipe.transform(input, createMetadata('long'))).toThrow(
        BadRequestException,
      );
    });
  });

  describe('Optional + range együtt — findNearby radius paraméter', () => {
    // A `findNearby` radius config-ja: { optional: true, min: 1, max: 50000 }
    let pipe: ParseFloatPipe;

    beforeEach(() => {
      pipe = new ParseFloatPipe({ optional: true, min: 1, max: 50000 });
    });

    it('undefined-ot ad vissza, ha az érték hiányzik', () => {
      expect(
        pipe.transform(undefined, createMetadata('radius')),
      ).toBeUndefined();
    });

    it('feldolgozza az érvényes radius értéket', () => {
      expect(pipe.transform('20000', createMetadata('radius'))).toBe(20000);
    });

    it('elutasítja a min alatti radius-t', () => {
      expect(() => pipe.transform('0', createMetadata('radius'))).toThrow(
        BadRequestException,
      );
    });

    it('elutasítja a max feletti radius-t', () => {
      expect(() => pipe.transform('60000', createMetadata('radius'))).toThrow(
        BadRequestException,
      );
    });

    it('elutasítja az érvénytelen számot akkor is, ha optional=true', () => {
      // Az `optional: true` flag CSAK az undefined/üres string esetére érvényes —
      // hibás formátumú értéket akkor is hibásan kezeli.
      expect(() => pipe.transform('abc', createMetadata('radius'))).toThrow(
        BadRequestException,
      );
    });
  });
});