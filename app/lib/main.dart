import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Ez az új GPS csomag

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TobaccoMapPage(),
    );
  }
}

class TobaccoMapPage extends StatefulWidget {
  const TobaccoMapPage({super.key});

  @override
  State<TobaccoMapPage> createState() => _TobaccoMapPageState();
}

class _TobaccoMapPageState extends State<TobaccoMapPage> {
  List<dynamic> shops = [];
  bool isLoading = true;
  LatLng? myPosition; // Itt tároljuk a te pozíciódat (ha megvan)
  final Distance distanceCalculator = const Distance(); // Távolság számoló

  // Kezdőpont (Alapból Budapest, amíg nincs GPS jel)
  LatLng mapCenter = const LatLng(47.50712, 19.04557);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Ez a fő indító függvény: Először GPS, aztán boltok letöltése
  Future<void> _initializeData() async {
    await _determinePosition(); // Megpróbáljuk megszerezni a pozíciót
    await fetchShops();         // Letöltjük a boltokat
  }

  // GPS pozíció lekérése (Hivatalos Flutter recept)
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Megnézzük, be van-e kapcsolva a GPS
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('A helymeghatározás ki van kapcsolva.');
      return;
    }

    // 2. Megnézzük, van-e engedélyünk az appnak
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Az engedély megtagadva.');
        return;
      }
    }

    // 3. Ha minden oké, lekérjük a pozíciót
    Position position = await Geolocator.getCurrentPosition();
    
    setState(() {
      myPosition = LatLng(position.latitude, position.longitude);
      mapCenter = myPosition!; // A térkép közepét is ide tesszük
    });
    print("Saját pozícióm: $myPosition");
  }

  Future<void> fetchShops() async {
    try {
      const String baseUrl = 'http://localhost:3000/shops';
      var response = await Dio().get(baseUrl);
      
      setState(() {
        shops = response.data;
        isLoading = false;
      });
    } catch (e) {
      print("HIBA: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Térkép'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Gombnyomásra újra megkeressük magunkat
              _determinePosition();
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 15.0,
                // 1. JAVÍTÁS: Forgatás tiltása
                // Megmondjuk, hogy csak a 'drag' (húzás) és 'zoom' engedélyezett.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'hu.csakos.tobacco_finder',
                  // 2. JAVÍTÁS: Élesebb kép (Retina mód)
                  // Ez "tömöríti" a pixeleket, így nem lesz homályos a telefonon.
                  retinaMode: true, 
                ),
                
                // 1. Réteg: A saját pozícióm (Kék pötty)
                if (myPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: myPosition!,
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 50,
                        ),
                      ),
                    ],
                  ),

                // 2. Réteg: A boltok (Piros pöttyök)
                MarkerLayer(
                  markers: shops.map((shop) {
                    double lat = shop['lat'];
                    double long = shop['long'];
                    LatLng shopLocation = LatLng(lat, long);

                    return Marker(
                      point: shopLocation,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          // Távolság számítás
                          String distanceText = "Ismeretlen távolság";
                          if (myPosition != null) {
                            double distInMeters = distanceCalculator.as(LengthUnit.Meter, myPosition!, shopLocation);
                            if (distInMeters > 1000) {
                              distanceText = "${(distInMeters / 1000).toStringAsFixed(1)} km";
                            } else {
                              distanceText = "${distInMeters.round()} m";
                            }
                          }

                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return Container(
                                padding: const EdgeInsets.all(16.0),
                                height: 280,
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shop['name'],
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_walk, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Távolság tőled: $distanceText",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        const Icon(Icons.map, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('${shop['city']}, ${shop['address']}'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    const Row(
                                      children: [
                                        Icon(Icons.access_time, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text("Nyitvatartás: 06:00 - 22:00"),
                                      ],
                                    ),

                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.close),
                                        label: const Text("Bezárás"),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}