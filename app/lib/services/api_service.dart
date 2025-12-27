import 'package:dio/dio.dart';
import '../models/shop.dart';

class ApiService {
  final Dio _dio = Dio();
  // Mivel van 'adb reverse', a localhost működik
  final String _baseUrl = 'http://localhost:3000/shops';

  Future<List<Shop>> fetchShops() async {
    try {
      final response = await _dio.get(_baseUrl);
      
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        // Átalakítjuk a JSON listát Shop objektumok listájává
        return data.map((json) => Shop.fromJson(json)).toList();
      } else {
        throw Exception('Hiba a betöltéskor');
      }
    } catch (e) {
      print("API Hiba: $e");
      return []; // Hiba esetén üres listát adunk vissza
    }
  }
}