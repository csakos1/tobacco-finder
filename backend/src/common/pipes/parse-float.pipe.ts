import {
  PipeTransform,
  Injectable,
  ArgumentMetadata,
  BadRequestException,
} from '@nestjs/common';

// ---------------------------------------------------------------
// CUSTOM PARSEFLOAT PIPE
//
// A NestJS beépített ParseFloatPipe-ja nem ellenőrzi a tartományt,
// és a NaN-t sem kezeli megbízhatóan minden verzióban.
//
// Ez a pipe:
//   1. Érvényes számot vár (NaN, Infinity, üres string → 400)
//   2. Opcionális min/max tartományellenőrzés
//
// Használat:
//   @Query('lat', new ParseFloatPipe({ min: -90, max: 90 })) lat: number
// ---------------------------------------------------------------

export interface ParseFloatPipeOptions {
  /** Minimális megengedett érték (inkluzív). */
  min?: number;
  /** Maximális megengedett érték (inkluzív). */
  max?: number;
  /** Ha true, a paraméter opcionális — undefined-ot átenged. */
  optional?: boolean;
}

@Injectable()
export class ParseFloatPipe implements PipeTransform<string, number | undefined> {
  private readonly min?: number;
  private readonly max?: number;
  private readonly optional: boolean;

  constructor(private readonly options: ParseFloatPipeOptions = {}) {
    this.min = options.min;
    this.max = options.max;
    this.optional = options.optional ?? false;
  }

  transform(value: string | undefined, metadata: ArgumentMetadata): number | undefined {
    // Opcionális paraméter: ha nincs megadva, átengedjük
    if (this.optional && (value === undefined || value === '')) {
      return undefined;
    }

    // Kötelező paraméter hiányzik
    if (value === undefined || value === '') {
      throw new BadRequestException(
        `A(z) "${metadata.data}" paraméter megadása kötelező.`,
      );
    }

    const parsed = parseFloat(value);

    // NaN vagy Infinity ellenőrzés
    if (!Number.isFinite(parsed)) {
      throw new BadRequestException(
        `A(z) "${metadata.data}" paraméter érvényes szám kell legyen, kapott: "${value}".`,
      );
    }

    // Tartomány-ellenőrzés
    if (this.min !== undefined && parsed < this.min) {
      throw new BadRequestException(
        `A(z) "${metadata.data}" paraméter nem lehet kisebb, mint ${this.min} (kapott: ${parsed}).`,
      );
    }

    if (this.max !== undefined && parsed > this.max) {
      throw new BadRequestException(
        `A(z) "${metadata.data}" paraméter nem lehet nagyobb, mint ${this.max} (kapott: ${parsed}).`,
      );
    }

    return parsed;
  }
}