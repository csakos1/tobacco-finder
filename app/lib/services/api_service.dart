import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Kell a compute-hoz
import '../models/shop.dart';
// Ha a config fájlod máshol van, lehet, hogy javítanod kell az importot,
// de az eredeti fájlodban így volt:
import '../config.dart'; // VAGY import '../config.dart'; attól függ mi a fájl neve nálad!

class ApiService {
  final Dio _dio = Dio();

  // FONTOS: Ellenőrizd, hogy a Config.apiUrl végén van-e '/shops' vagy nincs.
  // Az eredeti kódod alapján a Config.apiUrl valószínűleg így néz ki: "http://ip:3000/shops"
  // Ha így van, akkor a lenti kód helyes.
  final String _baseUrl = Config.apiUrl;

  // 1. ÖSSZES BOLT LEKÉRÉSE (Régi, de meghagyjuk tartaléknak)
  Future<List<Shop>> fetchShops() async {
    try {
      final response = await _dio.get(_baseUrl);

      if (response.statusCode == 200) {
        return await compute(_parseShops, response.data);
      } else {
        throw Exception('Hiba a betöltéskor');
      }
    } catch (e) {
      print("API Hiba (fetchShops): $e");
      return [];
    }
  }

  // 2. ÚJ: CSAK A KÖZELI BOLTOK LEKÉRÉSE (Ezt hiányolta a rendszer!)
  Future<List<Shop>> fetchNearby(double lat, double long) async {
    try {
      // Ha a _baseUrl vége "/shops", akkor ez "/shops/nearby" lesz, ami tökéletes.
      final response = await _dio.get(
        '$_baseUrl/nearby',
        queryParameters: {
          'lat': lat,
          'long': long,
          'radius': 20000, // 20 km-es körzet (állíthatod kisebbre is)
        },
      );

      if (response.statusCode == 200) {
        // Ugyanazt a parse logikát használjuk
        return await compute(_parseShops, response.data);
      } else {
        throw Exception('Hiba a betöltéskor');
      }
    } catch (e) {
      print("API Hiba (fetchNearby): $e");
      return [];
    }
  }

  // Ez a függvény fut a háttérben (top-level vagy static kell legyen)
  static List<Shop> _parseShops(dynamic responseBody) {
    final List<dynamic> data = responseBody;
    return data.map((json) => Shop.fromJson(json)).toList();
  }
}
