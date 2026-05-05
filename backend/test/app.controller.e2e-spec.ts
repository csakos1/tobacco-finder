// test/app.controller.e2e-spec.ts
//
// Az AppController (GET /) smoke-szintű E2E tesztje.
//
// Az AppController jelenleg csak az AppService.getHello() értékét adja
// vissza — egy plain string. Ez a teszt nem köti magát a string pontos
// tartalmához (az implementáció részlete), csak azt biztosítja, hogy
// a route létezik, válaszol, és a NestJS app-bootstrap helyesen
// regisztrálja a globális dependenciákat (ValidationPipe stb.).

import { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { bootstrapTestApp } from './helpers/app-bootstrap';

describe('App — Root végpont (E2E)', () => {
  let app: INestApplication;
  let close: () => Promise<void>;

  beforeAll(async () => {
    const bootstrapped = await bootstrapTestApp();
    app = bootstrapped.app;
    close = bootstrapped.close;
  });

  afterAll(async () => {
    await close();
  });

  it('200-zal és nem üres szöveges válasszal tér vissza GET / kérésre', async () => {
    // Act
    const response = await request(app.getHttpServer()).get('/');

    // Assert
    expect(response.status).toBe(200);
    // A getHello() string-et ad vissza, NestJS-ben text/html-ként megy
    // — ezért a response.text-et nézzük, nem a body-t.
    expect(typeof response.text).toBe('string');
    expect(response.text.length).toBeGreaterThan(0);
  });
});