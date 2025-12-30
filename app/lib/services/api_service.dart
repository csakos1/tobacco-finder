import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Kell a compute-hoz
import '../models/shop.dart';
import '../config.dart';

class ApiService {
  final Dio _dio = Dio();
  // Android Emulatorhoz: 10.0.2.2, Fizikai eszközhöz (adb reverse): localhost
  //inal String _baseUrl = 'http://localhost:3000/shops';
  final String _baseUrl = Config.apiUrl;

  Future<List<Shop>> fetchShops() async {
    try {
      final response = await _dio.get(_baseUrl);
      
      if (response.statusCode == 200) {
        // A JSON feldolgozást kiszervezzük egy külön izolált szálra
        return await compute(_parseShops, response.data);
      } else {
        throw Exception('Hiba a betöltéskor');
      }
    } catch (e) {
      print("API Hiba: $e");
      return [];
    }
  }

  // Ez a függvény fut a háttérben (top-level vagy static kell legyen)
  static List<Shop> _parseShops(dynamic responseBody) {
    final List<dynamic> data = responseBody;
    return data.map((json) => Shop.fromJson(json)).toList();
  }
}