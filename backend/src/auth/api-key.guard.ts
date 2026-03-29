import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { createHmac, timingSafeEqual } from 'crypto';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  /**
   * Timing-safe összehasonlítás két tetszőleges hosszúságú string között.
   *
   * Mindkét stringből HMAC-SHA256 digest-et készítünk (fix 32 byte),
   * majd a két digest-et hasonlítjuk össze `timingSafeEqual`-lal.
   * Így sem a kulcs tartalma, sem a hossza nem szivárog timing side-channel-en.
   */
  private isApiKeyValid(supplied: string, expected: string): boolean {
    const hmac = (value: string): Buffer =>
      createHmac('sha256', expected).update(value).digest();

    return timingSafeEqual(hmac(supplied), hmac(expected));
  }

  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const request = context.switchToHttp().getRequest();
    // Megnézzük, hogy a kérés fejlécében ott van-e az 'x-api-key'
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access
    const apiKeyHeader: unknown = request.headers['x-api-key'];
    // Kiolvassuk a szerver környezeti változóiból a titkos kulcsot
    const validApiKey = process.env.API_KEY;

    if (!validApiKey) {
      console.error('CRITICAL: API_KEY nincs beállítva a .env fájlban!');
      return false;
    }

    // Ha a header hiányzik vagy nem string, azonnal elutasítjuk
    if (typeof apiKeyHeader !== 'string' || apiKeyHeader.length === 0) {
      throw new UnauthorizedException('Hibás vagy hiányzó API kulcs');
    }

    // Timing-safe összehasonlítás
    if (this.isApiKeyValid(apiKeyHeader, validApiKey)) {
      return true;
    }

    throw new UnauthorizedException('Hibás vagy hiányzó API kulcs');
  }
}