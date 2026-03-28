// app/lib/services/geocoding_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/place_suggestion.dart';

class GeocodingService {
  final Dio _dio = Dio();

  /// Magyarország bounding box-a a Photon API szűréséhez.
  /// Formátum: minLon,minLat,maxLon,maxLat
  /// Ez biztosítja, hogy csak magyar találatokat kapjunk ANÉLKÜL,
  /// hogy szöveges suffixet fűznénk a query-hez — ami házszámos
  /// kereséseknél megtöri a cím-elemzőt.
  static const String _hungaryBbox = '16.1,45.7,22.9,48.6';

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().length < 3) return [];

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
      return features.map((f) => PlaceSuggestion.fromJson(f)).toList();
    } catch (e) {
      debugPrint('Geocoding hiba: $e');
      return [];
    }
  }
}
