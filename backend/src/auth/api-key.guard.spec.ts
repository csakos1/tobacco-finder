// src/auth/api-key.guard.spec.ts

import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ApiKeyGuard } from './api-key.guard';

describe('ApiKeyGuard', () => {
  let guard: ApiKeyGuard;

  // Az eredeti API_KEY env változó értéke a tesztek futása ELŐTT.
  // Minden teszt után visszaállítjuk, hogy a tesztek ne szivárogjanak
  // egymásba és a fejlesztői .env se sérüljön.
  let originalApiKey: string | undefined;

  // Helper: mock ExecutionContext létrehozása adott header objektummal.
  // A NestJS ExecutionContext-je valójában sok mindent tud, de a guardunk
  // csak ezt a két metódust hívja — elég ennyi mockot építeni.
  const createMockContext = (
    headers: Record<string, unknown>,
  ): ExecutionContext => {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ headers }),
      }),
    } as unknown as ExecutionContext;
  };

  beforeEach(() => {
    // Minden teszt friss guard példánnyal indul — nincs megosztott állapot.
    guard = new ApiKeyGuard();

    // Lementjük az env változó eredeti értékét.
    originalApiKey = process.env.API_KEY;

    // Elnyomjuk a console.error-t, hogy ne szennyezze a teszt kimenetet
    // amikor a "missing API_KEY" ágat teszteljük (a guard ott logol).
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    // Visszaállítjuk az env változót pontosan abba az állapotba,
    // ahogy a teszt előtt volt — figyelembe véve, hogy lehet, hogy
    // eredetileg nem is volt definiálva (undefined).
    if (originalApiKey === undefined) {
      delete process.env.API_KEY;
    } else {
      process.env.API_KEY = originalApiKey;
    }

    // Visszaállítjuk az összes mockolt függvényt (köztük a console.error-t).
    jest.restoreAllMocks();
  });

  // ---------------------------------------------------------------
  // Csoport 1 — Hibás szerver konfiguráció
  // ---------------------------------------------------------------
  describe('amikor a szerver helytelenül van konfigurálva', () => {
    it('false-ot ad vissza, ha a process.env.API_KEY nincs beállítva', () => {
      // Arrange
      delete process.env.API_KEY;
      const context = createMockContext({ 'x-api-key': 'bármi' });

      // Act
      const result = guard.canActivate(context);

      // Assert
      expect(result).toBe(false);
    });

    it('false-ot ad vissza, ha az API_KEY üres string', () => {
      // Üres string falsy, tehát az `if (!validApiKey)` ágat veszi.
      // Arrange
      process.env.API_KEY = '';
      const context = createMockContext({ 'x-api-key': 'bármi' });

      // Act
      const result = guard.canActivate(context);

      // Assert
      expect(result).toBe(false);
    });
  });

  // ---------------------------------------------------------------
  // Csoport 2 — Helyes szerver konfiguráció esetén a kérés validációja
  // ---------------------------------------------------------------
  describe('amikor érvényes API_KEY van beállítva', () => {
    const VALID_KEY = 'titkos-teszt-kulcs-123';

    beforeEach(() => {
      process.env.API_KEY = VALID_KEY;
    });

    it('true-t ad vissza, ha a header pontosan a helyes kulcsot tartalmazza', () => {
      // Arrange
      const context = createMockContext({ 'x-api-key': VALID_KEY });

      // Act
      const result = guard.canActivate(context);

      // Assert
      expect(result).toBe(true);
    });

    it('UnauthorizedException-t dob, ha az x-api-key header hiányzik', () => {
      // Arrange
      const context = createMockContext({});

      // Act + Assert (kivételvárás esetén egybe vonjuk)
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('UnauthorizedException-t dob, ha az x-api-key érték üres string', () => {
      // Arrange
      const context = createMockContext({ 'x-api-key': '' });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('UnauthorizedException-t dob, ha az x-api-key undefined', () => {
      // Arrange
      const context = createMockContext({ 'x-api-key': undefined });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('UnauthorizedException-t dob, ha az x-api-key tömb (nem string)', () => {
      // Express duplikált header esetén tömböt ad vissza — biztosítanunk kell,
      // hogy ezt is elutasítjuk, nem futunk bele típushibába.
      // Arrange
      const context = createMockContext({ 'x-api-key': ['kulcs1', 'kulcs2'] });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('UnauthorizedException-t dob, ha a kulcs egyszerűen rossz', () => {
      // Arrange
      const context = createMockContext({ 'x-api-key': 'teljesen-rossz-kulcs' });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('UnauthorizedException-t dob, ha a kulcs csak prefixe a helyesnek', () => {
      // Védelem timing-attack jellegű részleges egyezések ellen.
      // Egy naiv string-összehasonlítás karakterenként megy és időben szivárog —
      // a HMAC + timingSafeEqual kombóval ez nem lehetséges, és viselkedési
      // szinten a prefix sem lehet érvényes.
      // Arrange
      const context = createMockContext({ 'x-api-key': VALID_KEY.slice(0, 5) });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
    });

    it('a hibaüzenet pontosan "Hibás vagy hiányzó API kulcs"', () => {
      // Az API kontraktus része, hogy MILYEN üzenetet kap a kliens —
      // egy belső kódváltás esetén ez ne tudjon észrevétlenül megváltozni.
      // Arrange
      const context = createMockContext({ 'x-api-key': 'rossz' });

      // Act + Assert
      expect(() => guard.canActivate(context)).toThrow(
        'Hibás vagy hiányzó API kulcs',
      );
    });
  });
});