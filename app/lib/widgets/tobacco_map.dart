import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class TobaccoMap extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? userLocation; // Figyelem: Ez most már a google_maps_flutter LatLng-je!
  final Function(Shop) onShopSelected;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.userLocation,
    required this.onShopSelected,
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shops != widget.shops) {
      _updateMarkers();
    }
    if (oldWidget.userLocation != widget.userLocation && widget.userLocation != null) {
      _moveCameraToUser();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = widget.shops.map((shop) {
        final isOpen = ShopLogic.isOpenNow(shop.openingHours);
        
        // Mivel a Google Maps alap markere színezhető (hue), 
        // a nyitva lévőket zöldre (vagy alapértelmezett pirosra), 
        // a zárva lévőket esetleg más színűre állíthatjuk.
        // Itt most standard pirosat használunk, de a snippet-ben jelezzük a státuszt.
        
        return Marker(
          markerId: MarkerId(shop.name + shop.address), // Egyedi ID
          position: LatLng(shop.lat ?? 0, shop.long ?? 0),
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: isOpen ? "Nyitva" : "Zárva",
            onTap: () => widget.onShopSelected(shop),
          ),
          onTap: () => widget.onShopSelected(shop),
          // Ikon testreszabása (opcionális, most standard)
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isOpen ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
          ),
        );
      }).toSet();
    });
  }

  Future<void> _moveCameraToUser() async {
    if (widget.userLocation == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(widget.userLocation!));
  }

  @override
  Widget build(BuildContext context) {
    // Kezdőpozíció: Ha nincs user location, akkor Budapest közepe
    final initialTarget = widget.userLocation ?? const LatLng(47.4979, 19.0402);

    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: 14.0,
      ),
      markers: _markers,
      myLocationEnabled: true, // Ez mutatja a kék pöttyöt (ha van engedély)
      myLocationButtonEnabled: false, // Saját gombunk van rá a főképernyőn
      zoomControlsEnabled: false, // Letisztultabb UI
      mapToolbarEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
        // Sötét mód beállítása (opcionális)
        if (Theme.of(context).brightness == Brightness.dark) {
           // Itt lehetne betölteni JSON stílust: controller.setMapStyle(...)
        }
      },
    );
  }
}