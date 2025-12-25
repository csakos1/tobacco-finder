import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io'; // EZT ADTUK HOZZÁ (hogy felismerje a rendszert)

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dohánybolt Kereső',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TobaccoShopsPage(),
    );
  }
}

class TobaccoShopsPage extends StatefulWidget {
  const TobaccoShopsPage({super.key});

  @override
  State<TobaccoShopsPage> createState() => _TobaccoShopsPageState();
}

class _TobaccoShopsPageState extends State<TobaccoShopsPage> {
  List<dynamic> shops = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchShops();
  }

  Future<void> fetchShops() async {
    try {
      // ITT A JAVÍTÁS:
      // Megnézzük, hogy Androidon vagyunk-e.
      // Ha igen, akkor 10.0.2.2, ha Linux/Web/iOS, akkor localhost.
      String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000/shops' : 'http://localhost:3000/shops';
      
      print("Csatlakozás ide: $baseUrl"); // Hogy lássuk a terminálban mit csinál

      var response = await Dio().get(baseUrl);
      
      setState(() {
        shops = response.data;
        isLoading = false;
      });
    } catch (e) {
      print("HIBA TÖRTÉNT: $e"); // Ez írja ki a hibát a terminálba
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dohányboltok'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : shops.isEmpty 
              ? const Center(child: Text("Nincs megjeleníthető bolt.")) 
              : ListView.builder(
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: const Icon(Icons.store, color: Colors.brown),
                        title: Text(shop['name']),
                        subtitle: Text('${shop['city']}, ${shop['address']}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isLoading = true;
          });
          fetchShops();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}