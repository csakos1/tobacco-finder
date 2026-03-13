import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerGenerator {
  static const Color primaryColor = Color(0xFF28436C);

  static Future<BitmapDescriptor> createShopMarker(bool isOpen) async {
    const double logicalSize = 45.0; // Az általad kért tökéletes méret
    const double dpr = 3.0; // 3x-os felbontás a tűéles képért!
    const double physicalSize = logicalSize * dpr;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Felskálázzuk a vásznat a fizikai méretre
    canvas.scale(dpr, dpr);

    // Innentől kezdve úgy rajzolunk, mintha simán 45 pixelre dolgoznánk
    final TextPainter iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    iconPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: logicalSize,
        fontFamily: Icons.location_on.fontFamily,
        color: primaryColor,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(canvas, const Offset(0.0, 0.0));

    final Paint dotPaint = Paint()
      ..color = isOpen ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const Offset dotCenter = Offset(logicalSize / 2, logicalSize * 0.38);
    const double dotRadius = 6.5; // Az általad kért pötty méret

    canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    canvas.drawCircle(dotCenter, dotRadius, borderPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      physicalSize.toInt(),
      physicalSize.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // Itt történik a varázslat: 135px képet adunk, de 45px méretre kényszerítjük!
    // (Megjegyzés: Ha a "size:" paramétert aláhúzná pirossal a Dart, akkor cseréld le a 'fromBytes'-t 'bytes'-ra)
    return BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
      size: const Size(logicalSize, logicalSize),
    );
  }

  static Future<BitmapDescriptor> createClusterMarker(int clusterSize) async {
    const double logicalSize = 50.0; // Az általad kért klaszter méret
    const double dpr = 3.0;
    const double physicalSize = logicalSize * dpr;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(dpr, dpr);

    final Paint paint = Paint()..color = primaryColor;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const Offset center = Offset(logicalSize / 2, logicalSize / 2);
    canvas.drawCircle(center, logicalSize / 2.2, paint);
    canvas.drawCircle(center, logicalSize / 2.2, borderPaint);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: clusterSize.toString(),
      style: const TextStyle(
        fontSize: 18.0, // Az általad kért betűméret
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      physicalSize.toInt(),
      physicalSize.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
      size: const Size(logicalSize, logicalSize),
    );
  }
}
