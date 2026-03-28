// app/lib/services/geocoding_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/place_suggestion.dart';
import '../models/geocoding_result.dart';

class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// Magyarország bounding box-a a Photon API szűréséhez.
  /// Formátum: minLon,minLat,maxLon,maxLat
  /// Ez biztosítja, hogy csak magyar találatokat kapjunk ANÉLKÜL,
  /// hogy szöveges suffixet fűznénk a query-hez — ami házszámos
  /// kereséseknél megtöri a cím-elemzőt.
  static const String _hungaryBbox = '16.1,45.7,22.9,48.6';

  /// Hely keresés a Photon API-n keresztül.
  ///
  /// Visszatérés:
  /// - [GeocodingSuccess] sikeres válasz esetén (a lista lehet üres).
  /// - [GeocodingError] hálózati/szerver/timeout hiba esetén,
  ///   kategorizált [GeocodingErrorKind]-dal.
  Future<GeocodingResult> searchPlaces(String query) async {
    if (query.trim().length < 3) return const GeocodingSuccess([]);

    try {
      final response = await _dio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q': query,
          'limit': 15,
          'bbox': _hungaryBbox,
          // A lang paramétert szándékosan kivettük, mert a Photon API
          // nyilvános szervere nem támogatja a 'hu' kódot és 400-as hibát dob!
        },
        options: Options(
          headers: {
            'User-Agent': 'TobaccoFinderApp/1.0 (hu.csakos.tobacco_finder)',
          },
        ),
      );

      final features = response.data['features'] as List;
      final suggestions = features
          .map((f) => PlaceSuggestion.fromJson(f))
          .toList();
      return GeocodingSuccess(suggestions);
    } on DioException catch (e) {
      final kind = _classifyDioError(e);
      debugPrint('Geocoding hiba [$kind]: ${e.message}');
      return GeocodingError(kind: kind, debugMessage: e.message);
    } catch (e) {
      debugPrint('Geocoding váratlan hiba: $e');
      return GeocodingError(
        kind: GeocodingErrorKind.unknown,
        debugMessage: e.toString(),
      );
    }
  }

  /// Dio hibák kategorizálása a UI számára értelmezhető típusokba.
  GeocodingErrorKind _classifyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GeocodingErrorKind.timeout;

      case DioExceptionType.connectionError:
        return GeocodingErrorKind.network;

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode >= 500) return GeocodingErrorKind.server;
        // 4xx hibák (pl. rossz request) → ismeretlen kategória,
        // mert ezek a mi oldalunkról konfigurációs hibák.
        return GeocodingErrorKind.unknown;

      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return GeocodingErrorKind.unknown;
    }
  }
}
