![Flutter](https://img.shields.io/badge/Flutter-3.38.1-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10.1-0175C2?logo=dart&logoColor=white)
![NestJS](https://img.shields.io/badge/NestJS-11.0.1-E0234E?logo=nestjs&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7.3-3178C6?logo=typescript&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-PostGIS-4169E1?logo=postgresql&logoColor=white)
![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?logo=prisma&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?logo=android)
![License](https://img.shields.io/badge/License-MIT-green)

# Tobacco Finder — Dohánybolt Kereső

A full-stack mobile application that helps users in Hungary locate nearby tobacco shops on an interactive map.

---

## Features

- Real-time GPS-based shop discovery
- Interactive map with marker clustering
- Address search powered by the Photon geocoding API
- Opening hours display per shop
- API key-based backend authentication

---

## Architecture
```
├── app/          # Flutter mobile client (iOS & Android)
└── backend/      # NestJS REST API
```

### Frontend — Flutter
- **State management:** Native (`ChangeNotifier`, `ValueNotifier`)
- **Map:** `google_maps_flutter` with cluster manager
- **HTTP:** `dio`
- **Location:** `geolocator`

### Backend — NestJS
- **Framework:** NestJS (TypeScript)
- **ORM:** Prisma
- **Database:** PostgreSQL + PostGIS (geospatial queries)
- **Auth:** API key guard via `x-api-key` header

---

## Database

The backend uses PostgreSQL with the PostGIS extension for efficient radius-based geospatial queries.

Prisma handles migrations and the ORM layer. The core model is `TobaccoShop`, storing name, address, city, opening hours (JSONB), and a `geography(Point, 4326)` location field indexed with GIST.

---

## Security

All API endpoints are protected by an `ApiKeyGuard`. Requests must include a valid `x-api-key` header matching the server-side `API_KEY` environment variable.

---

## License

This project is licensed under the [MIT License](LICENSE).
