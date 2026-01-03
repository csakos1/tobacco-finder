import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Observable } from 'rxjs';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const request = context.switchToHttp().getRequest();
    // Megnézzük, hogy a kérés fejlécében ott van-e az 'x-api-key'
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access
    const apiKeyHeader = request.headers['x-api-key'];
    // Kiolvassuk a szerver környezeti változóiból a titkos kulcsot
    const validApiKey = process.env.API_KEY;

    if (!validApiKey) {
      console.error('CRITICAL: API_KEY nincs beállítva a .env fájlban!');
      return false; // Ha nincs kulcs a szerveren, senki nem léphet be
    }

    // Összehasonlítjuk a kapott kulcsot az igazival
    if (apiKeyHeader === validApiKey) {
      return true;
    } else {
      throw new UnauthorizedException('Hibás vagy hiányzó API kulcs');
    }
  }
}
