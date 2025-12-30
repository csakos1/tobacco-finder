import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class TobaccoMap extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? userLocation;
  final Function(Shop) onShopSelected;
  final Function(GoogleMapController) onMapCreated;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.userLocation,
    required this.onShopSelected,
    required this.onMapCreated,
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  Set<Marker> _markers = {};
  BitmapDescriptor? _openMarkerIcon;
  BitmapDescriptor? _closedMarkerIcon;
  bool _iconsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Csak egyszer generáljuk le az ikonokat induláskor!
    _generateIcons();
  }

  /// Ez a függvény rajzolja le pixelre pontosan azt a dizájnt, amit a flutter_map-nél használtál.
  /// Stack(Icon + Container) helyett Canvas-ra rajzoljuk ugyanazt.
  Future<void> _generateIcons() async {
    // A színeket a Theme-ből vagy fixen is vehetjük, itt a te kódod alapján fixálom a pirosas színt (primary)
    // Ha a primary színed más, itt átírhatod.
    const Color primaryColor = Color(0xFF6750A4); // Material 3 default primary, vagy add meg a sajátod
    
    _openMarkerIcon = await _createMarkerBitmap(primaryColor, true);
    _closedMarkerIcon = await _createMarkerBitmap(primaryColor, false);

    if (mounted) {
      setState(() {
        _iconsLoaded = true;
        _updateMarkers();
      });
    }
  }

  Future<BitmapDescriptor> _createMarkerBitmap(Color color, bool isOpen) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Méretek a te kódod alapján (kicsit nagyobbra véve a felbontás miatt, majd a térkép leméretezi)
    const double size = 120.0; 
    const double iconSize = 100.0;

    // 1. Az alap PIN ikon (Icons.location_on)
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: Icons.location_on.fontFamily,
        color: color, 
      ),
    );
    textPainter.layout();
    // Középre igazítás
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, 0));

    // 2. A kis pötty (Status Indicator)
    final Paint dotPaint = Paint()
      ..color = isOpen ? const Color(0xFF4CAF50) : const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Vastagabb keret a nagy felbontás miatt

    // Pozíció számolása: "top: 10" arányosan
    const double circleRadius = 18.0;
    const Offset circleCenter = Offset(size / 2, 30.0); // Kicsit lejjebb a tetejétől

    // Pötty kirajzolása
    canvas.drawCircle(circleCenter, circleRadius, dotPaint);
    // Fehér keret
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final dynamic byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Csak akkor frissítünk, ha a boltok listája változott, vagy most töltődtek be az ikonok
    if (oldWidget.shops != widget.shops || (_iconsLoaded && _markers.isEmpty)) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    if (!_iconsLoaded) return;

    // OPTIMALIZÁCIÓ: Nem használunk "map" loop-ot minden egyes renderelésnél, ha nem muszáj.
    final markers = widget.shops.map((shop) {
      final isOpen = ShopLogic.isOpenNow(shop.openingHours);
      
      return Marker(
        markerId: MarkerId(shop.id.toString()),
        position: LatLng(shop.lat ?? 0, shop.long ?? 0),
        // Itt használjuk az előre legenerált képeket -> Nincs akadozás!
        icon: isOpen ? _openMarkerIcon! : _closedMarkerIcon!,
        infoWindow: InfoWindow(
          title: shop.name,
          snippet: isOpen ? "Nyitva" : "Zárva",
          onTap: () => widget.onShopSelected(shop),
        ),
        onTap: () => widget.onShopSelected(shop),
      );
    }).toSet();

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = widget.userLocation ?? const LatLng(47.4979, 19.0402);

    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: 15.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // Fontos: a kontroller átadása a szülőnek
      onMapCreated: (controller) {
        widget.onMapCreated(controller);
      },
    );
  }
}