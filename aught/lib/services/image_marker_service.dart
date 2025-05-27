import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ImageMarkerService {
  /// Creates a circular image marker from an asset
  static Future<Uint8List> createCircularMarker({
    required String assetPath,
    int size = 600,
  }) async {
    try {
      // Load the original image
      final ByteData byteData = await rootBundle.load(assetPath);
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Create a circular image
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Create circular clipping path
      final Paint paint = Paint()..isAntiAlias = true;
      final Rect rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
      canvas.clipPath(Path()..addOval(rect));

      // Calculate scaling to fit image without stretching
      final double imageWidth = image.width.toDouble();
      final double imageHeight = image.height.toDouble();
      final double canvasSize = size.toDouble();

      // Calculate scale to fit the image (cover the entire circle)
      final double scale = math.max(
        canvasSize / imageWidth,
        canvasSize / imageHeight,
      );

      // Calculate the scaled dimensions
      final double scaledWidth = imageWidth * scale;
      final double scaledHeight = imageHeight * scale;

      // Calculate offset to center the image
      final double offsetX = (canvasSize - scaledWidth) / 2;
      final double offsetY = (canvasSize - scaledHeight) / 2;

      // Draw the image centered and scaled
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, imageWidth, imageHeight),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        paint,
      );

      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image circularImage = await picture.toImage(size, size);

      // Convert to bytes
      final ByteData? pngBytes = await circularImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return pngBytes!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error creating circular marker: $e');
      rethrow;
    }
  }
}
