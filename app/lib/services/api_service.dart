import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Kell a compute-hoz
import '../models/shop.dart';
import '../config.dart';

class ApiService {
  final Dio _dio = Dio();

  final String _baseUrl = Config.apiUrl;

  // ---------------------------------------------------------------
  // ÖSSZES BOLT LEKÉRÉSE (Tartalék, ha nincs GPS pozíció)
  //
  // Hiba esetén exception-t dob, hogy a hívó fél (controller)
  // értesülhessen róla és hibaüzenetet tudjon mutatni a usernek.
  // ---------------------------------------------------------------
  Future<List<Shop>> fetchShops() async {
    try {
      final response = await _dio.get(_baseUrl);

      if (response.statusCode == 200) {
        return await compute(_parseShops, response.data);
      } else {
        throw Exception('Hiba a betöltéskor (HTTP ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("API Hiba (fetchShops): $e");
      throw Exception('Nem sikerült csatlakozni a szerverhez.');
    }
  }

  // ---------------------------------------------------------------
  // CSAK A KÖZELI BOLTOK LEKÉRÉSE (Elsődleges, GPS-alapú lekérés)
  // ---------------------------------------------------------------
  Future<List<Shop>> fetchNearby(double lat, double long) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/nearby',
        queryParameters: {
          'lat': lat,
          'long': long,
          'radius': 20000, // 20 km-es körzet
        },
      );

      if (response.statusCode == 200) {
        return await compute(_parseShops, response.data);
      } else {
        throw Exception('Hiba a betöltéskor (HTTP ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("API Hiba (fetchNearby): $e");
      throw Exception('Nem sikerült csatlakozni a szerverhez.');
    }
  }

  // Ez a függvény fut a háttérben (top-level vagy static kell legyen)
  static List<Shop> _parseShops(dynamic responseBody) {
    final List<dynamic> data = responseBody;
    return data.map((json) => Shop.fromJson(json)).toList();
  }
}
