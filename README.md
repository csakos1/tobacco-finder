![Flutter](https://img.shields.io/badge/Flutter-3.38.1-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10.1-0175C2?logo=dart&logoColor=white)
![NestJS](https://img.shields.io/badge/NestJS-11.0.1-E0234E?logo=nestjs&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7.3-3178C6?logo=typescript&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-PostGIS-4169E1?logo=postgresql&logoColor=white)
![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?logo=prisma&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?logo=android)
![License](https://img.shields.io/badge/License-MIT-green)

# Tobacco Finder — Dohánybolt Kereső

A full-stack mobile application that helps users in Hungary locate nearby tobacco shops on an interactive map.

---

## Features

- **GPS-based shop discovery** — Automatic nearby shop loading on launch with background position refinement
- **Interactive map** — Google Maps with marker clustering, custom map styles, and animated camera transitions
- **Address search** — Place search powered by the Photon/Komoot geocoding API with type-aware zoom levels
- **Opening hours** — Per-shop opening hours display with overnight span logic
- **Shop filtering** — Filter by "Open now" or "Non-stop" shops
- **Navigation** — "Navigate here" button opens native maps (Apple Maps on iOS, Google Maps on Android)
- **Offline mode** — Automatic cache fallback with animated offline banner when the network is unavailable
- **Dark mode** — Full dark/light/system theme support with custom Google Maps styles for both modes
- **Settings** — Theme selector, haptic feedback toggle, app version display
- **Pull-to-refresh** — Refresh the shop list from the list view
- **Map panning fetch** — Automatically loads new shops as the user pans the map (debounced, 2 km threshold)
- **Memory management** — Bounded shop list (500-item cap) with distance-based pruning

---

## Architecture

```
├── app/                # Flutter mobile client (iOS & Android)
├── backend/            # NestJS REST API
├── deploy/             # Nginx config & Let's Encrypt bootstrap
└── docker-compose.yml  # Production orchestration
```

### Frontend — Flutter

- **State management:** Native (`ChangeNotifier`, `ValueNotifier`, `ListenableBuilder`)
- **Pattern:** Controller → Repository → Service layered architecture
- **Map:** `google_maps_flutter` with `google_maps_cluster_manager_2`
- **HTTP:** `dio` (with configurable timeouts)
- **Location:** `geolocator`
- **Persistence:** `shared_preferences` (cache, settings, last GPS position)
- **Navigation:** `url_launcher` (native maps deep-link)
- **Typography:** `google_fonts`

Key components:

| Layer | Class | Responsibility |
|-------|-------|----------------|
| Controller | `HomeController` | UI state orchestration, data loading lifecycle |
| Controller | `MapStateController` | Camera state, bearing, search pin, map reveal |
| Repository | `ShopRepository` | API fetch + cache fallback, merge, sort, filter, prune |
| Service | `ApiService` | HTTP calls to the backend via Dio |
| Service | `GeocodingService` | Photon/Komoot place search |
| Service | `LocationService` | GPS permission handling, position caching |
| Service | `ShopCacheService` | Offline cache read/write (JSON in SharedPreferences) |
| Service | `HapticService` | Centralized haptic feedback |
| Service | `AppSettings` | Singleton for theme, haptic toggle, initial map position |

### Backend — NestJS

- **Framework:** NestJS 11 (TypeScript)
- **ORM:** Prisma (raw SQL for PostGIS queries)
- **Database:** PostgreSQL 15 + PostGIS 3.3
- **Auth:** API key guard via `x-api-key` header (timing-safe HMAC-SHA256 comparison)
- **Rate limiting:** `@nestjs/throttler` — 100 requests / 60 seconds per IP (global)
- **Validation:** `class-validator` + `class-transformer` with global `ValidationPipe`

---

## API Endpoints

### Public (rate-limited: 100 req / 60s / IP)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/shops` | List all shops (paginated: `limit`, `offset`) |
| `GET` | `/shops/nearby?lat=&long=&radius=` | Find shops within radius (default 20 km, max 50 km) |
| `GET` | `/shops/:id` | Get a single shop by UUID |

### Protected (requires `x-api-key` header)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/shops` | Create a new shop |
| `PATCH` | `/shops/:id` | Update an existing shop |
| `DELETE` | `/shops/:id` | Delete a shop |

---

## Database

The backend uses PostgreSQL with the PostGIS extension for efficient radius-based geospatial queries.

Prisma handles migrations and the ORM layer. The core model is `TobaccoShop`, storing name, address, city, opening hours (JSONB), and a `geography(Point, 4326)` location field indexed with GIST.

All spatial queries use raw SQL (`ST_DWithin`, `ST_MakePoint`, `ST_SetSRID`) to leverage PostGIS natively.

---

## Infrastructure

The production stack runs on a **Linode Ubuntu VPS** via Docker Compose with four services:

| Service | Image | Role |
|---------|-------|------|
| `db` | `postgis/postgis:15-3.3` | PostgreSQL + PostGIS database |
| `backend` | Custom (Node 18 Alpine) | NestJS API server on port 3000 |
| `nginx` | `nginx:alpine` | Reverse proxy, HTTPS termination |
| `certbot` | `certbot/certbot` | Automatic Let's Encrypt certificate renewal (every 12h) |

Deployment configuration lives in `deploy/` (Nginx config, Let's Encrypt bootstrap script).

---

## Security

- **API key guard** — Write endpoints (`POST`, `PATCH`, `DELETE`) require a valid `x-api-key` header. Comparison uses HMAC-SHA256 + `timingSafeEqual` to prevent timing side-channel attacks.
- **Rate limiting** — Public read endpoints are globally rate-limited to 100 requests per 60 seconds per IP via `@nestjs/throttler`. Protected endpoints skip throttling (already guarded by the API key).
- **Input validation** — All incoming request bodies are validated by `class-validator` decorators through a global `ValidationPipe` (`whitelist`, `forbidNonWhitelisted`, `transform`). UUID path parameters use `ParseUUIDPipe`.
- **HTTPS** — Nginx terminates TLS with certificates from Let's Encrypt, auto-renewed by Certbot.

---

## License

This project is licensed under the [MIT License](LICENSE).
