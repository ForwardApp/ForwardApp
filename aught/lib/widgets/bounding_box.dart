import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math; // Import math for sqrt function
import '../services/supabase_service.dart'; // Add missing import

class BoundingBoxWidget extends StatefulWidget {
  final mp.MapboxMap? mapController;
  final bool isPanEnabled; // Add this parameter

  const BoundingBoxWidget({
    super.key, 
    this.mapController,
    this.isPanEnabled = true, // Default to true as requested
  });

  @override
  State<BoundingBoxWidget> createState() => _BoundingBoxWidgetState();
  
  static mp.PointAnnotationManager? _greenDotManager;
  static mp.PolygonAnnotationManager? _polygonManager;
  static mp.PolygonAnnotation? _boundingBoxPolygon;
  
  // Store current coordinates for dragging
  static double? _topLeftLat;
  static double? _topLeftLng;
  static double? _topRightLat;
  static double? _topRightLng;
  static double? _bottomRightLat;
  static double? _bottomRightLng;
  static double? _bottomLeftLat;
  static double? _bottomLeftLng;
  
  static bool _isDragging = false;
  static int _draggingCornerIndex = -1;
  
  // Method to update any corner position
  static Future<void> updateCornerPosition(mp.MapboxMap mapController, int cornerIndex, double lat, double lng) async {
    switch (cornerIndex) {
      case 0: // Top Left
        await updateTopLeftPosition(mapController, lat, lng);
        break;
      case 1: // Top Right
        await updateTopRightPosition(mapController, lat, lng);
        break;
      case 2: // Bottom Right
        await updateBottomRightPosition(mapController, lat, lng);
        break;
      case 3: // Bottom Left
        await updateBottomLeftPosition(mapController, lat, lng);
        break;
    }
  }
  
  // Check if a screen position is near a specific corner dot
  static Future<bool> isNearCorner(mp.MapboxMap mapController, Offset position, int cornerIndex) async {
    double? lat;
    double? lng;
    
    switch (cornerIndex) {
      case 0: // Top Left
        lat = _topLeftLat;
        lng = _topLeftLng;
        break;
      case 1: // Top Right
        lat = _topRightLat;
        lng = _topRightLng;
        break;
      case 2: // Bottom Right
        lat = _bottomRightLat;
        lng = _bottomRightLng;
        break;
      case 3: // Bottom Left
        lat = _bottomLeftLat;
        lng = _bottomLeftLng;
        break;
    }
    
    if (lat == null || lng == null) return false;
    
    // Convert screen position to map coordinates
    final screenCoord = mp.ScreenCoordinate(x: position.dx, y: position.dy);
    
    // Convert the corner's marker position to screen coordinates
    final markerPosition = await mapController.pixelForCoordinate(
      mp.Point(coordinates: mp.Position(lng, lat))
    );
    
    // Calculate distance between touch point and marker position
    final distance = _calculateDistance(
      position.dx, 
      position.dy, 
      markerPosition.x, 
      markerPosition.y
    );
    
    // Consider it a hit if the touch is within 50 pixels of the marker
    return distance < 50;
  }
  
  static void setDraggingState(bool isDragging, int cornerIndex) {
    _isDragging = isDragging;
    _draggingCornerIndex = isDragging ? cornerIndex : -1;
  }
  
  static Future<void> _updateDots(mp.MapboxMap mapController) async {
    try {
      if (_greenDotManager == null) {
        _greenDotManager = await mapController.annotations.createPointAnnotationManager();
      } else {
        // Clear existing dots
        await _greenDotManager!.deleteAll();
      }
      
      // Only create polygon manager once
      if (_polygonManager == null) {
        _polygonManager = await mapController.annotations.createPolygonAnnotationManager();
      }
      
      // Create dots for all four corners
      final List<Map<String, double>> squarePositions = [
        {'lat': _topLeftLat!, 'lng': _topLeftLng!}, // Top left - index 0
        {'lat': _topRightLat!, 'lng': _topRightLng!}, // Top right - index 1
        {'lat': _bottomRightLat!, 'lng': _bottomRightLng!}, // Bottom right - index 2
        {'lat': _bottomLeftLat!, 'lng': _bottomLeftLng!}, // Bottom left - index 3
      ];
      
      // Create dots with the dragged one being blue if it's being dragged
      for (int i = 0; i < squarePositions.length; i++) {
        final position = squarePositions[i];
        final Uint8List circleData = i == _draggingCornerIndex && _isDragging
            ? await _createBlueCircle()  // Blue circle for the dragged dot
            : await _createGreenCircle();
            
        final dotOptions = mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(position['lng']!, position['lat']!),
          ),
          image: circleData,
          iconSize: 1.0,
        );
        
        await _greenDotManager!.create(dotOptions);
      }
      
      // Create polygon options
      final polygonOptions = mp.PolygonAnnotationOptions(
        geometry: mp.Polygon(
          coordinates: [
            [
              mp.Position(_topLeftLng!, _topLeftLat!), // Top left
              mp.Position(_topRightLng!, _topRightLat!), // Top right
              mp.Position(_bottomRightLng!, _bottomRightLat!), // Bottom right
              mp.Position(_bottomLeftLng!, _bottomLeftLat!), // Bottom left
              mp.Position(_topLeftLng!, _topLeftLat!), // Close the polygon
            ]
          ],
        ),
        fillColor: 0x4000FF00, 
        fillOpacity: 0.3,
        fillOutlineColor: 0xFF00FF00, // Solid green border
      );
      
      // Instead of trying to delete the old polygon (which causes errors), 
      // just clear all polygons and create a new one
      try {
        if (_polygonManager != null) {
          await _polygonManager!.deleteAll(); // Delete all polygons instead of a specific one
        }
      } catch (e) {
        debugPrint('Error clearing polygons: $e');
        // Create polygon manager again if there was an error
        _polygonManager = await mapController.annotations.createPolygonAnnotationManager();
      }
      
      // Create new polygon and store reference
      _boundingBoxPolygon = await _polygonManager!.create(polygonOptions);
    } catch (e) {
      debugPrint('Error updating dots: $e');
    }
  }
  
  // Method to update the top left corner position
  static Future<void> updateTopLeftPosition(mp.MapboxMap mapController, double lat, double lng) async {
    _topLeftLat = lat;
    _topLeftLng = lng;
    
    await _updateDots(mapController);
  }
  
  // Method to update the top right corner position
  static Future<void> updateTopRightPosition(mp.MapboxMap mapController, double lat, double lng) async {
    _topRightLat = lat;
    _topRightLng = lng;
    
    await _updateDots(mapController);
  }
  
  // Method to update the bottom right corner position
  static Future<void> updateBottomRightPosition(mp.MapboxMap mapController, double lat, double lng) async {
    _bottomRightLat = lat;
    _bottomRightLng = lng;
    
    await _updateDots(mapController);
  }
  
  // Method to update the bottom left corner position
  static Future<void> updateBottomLeftPosition(mp.MapboxMap mapController, double lat, double lng) async {
    _bottomLeftLat = lat;
    _bottomLeftLng = lng;
    
    await _updateDots(mapController);
  }
  
  static Future<Uint8List> _createGreenCircle() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(const Offset(50, 50), 48, borderPaint);
    
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 50), 38, paint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  static Future<Uint8List> _createBlueCircle() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(const Offset(50, 50), 48, borderPaint);
    
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 50), 38, paint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  // Check if a screen position is near the top-left dot
  static Future<bool> isNearTopLeftDot(mp.MapboxMap mapController, Offset position) async {
    if (_topLeftLat == null || _topLeftLng == null) return false;
    
    // Convert screen position to map coordinates
    final screenCoord = mp.ScreenCoordinate(x: position.dx, y: position.dy);
    final mapCoord = await mapController.coordinateForPixel(screenCoord);
    
    // Convert the top-left marker position to screen coordinates
    final markerPosition = await mapController.pixelForCoordinate(
      mp.Point(coordinates: mp.Position(_topLeftLng!, _topLeftLat!))
    );
    
    // Calculate distance between touch point and marker position
    final distance = _calculateDistance(
      position.dx, 
      position.dy, 
      markerPosition.x, 
      markerPosition.y
    );
    
    // Consider it a hit if the touch is within 50 pixels of the marker
    return distance < 50;
  }
  
  // Helper to calculate distance between two points
  static double _calculateDistance(double x1, double y1, double x2, double y2) {
    return math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  }
  
  // Add the missing addGreenDotToMap method
  static Future<void> addGreenDotToMap(mp.MapboxMap mapController, double latitude, double longitude) async {
    try {
      // Store the center coordinates for the bounding box
      const double offset = 0.00035;
      
      // Calculate corner coordinates
      _topLeftLat = latitude + offset;
      _topLeftLng = longitude - offset;
      _topRightLat = latitude + offset;
      _topRightLng = longitude + offset;
      _bottomRightLat = latitude - offset;
      _bottomRightLng = longitude + offset;
      _bottomLeftLat = latitude - offset;
      _bottomLeftLng = longitude - offset;
      
      // Initialize managers if needed
      if (_greenDotManager != null) {
        await _greenDotManager!.deleteAll();
        _greenDotManager = null;
      }
      
      if (_polygonManager != null) {
        await _polygonManager!.deleteAll();
        _polygonManager = null;
      }

      // Create dot manager
      _greenDotManager = await mapController.annotations.createPointAnnotationManager();
      
      // Update the dots and polygon
      await _updateDots(mapController);
      
      debugPrint('Green dots with bounding box added at: $latitude, $longitude');
    } catch (e) {
      debugPrint('Error adding green dots with polygon: $e');
    }
  }
  
  // Method to save the current bounding box to the database
  static Future<void> saveBoundingBoxToDatabase(int safeZoneId, String locationName) async {
    if (_topLeftLat == null || _topLeftLng == null || 
        _topRightLat == null || _topRightLng == null || 
        _bottomRightLat == null || _bottomRightLng == null || 
        _bottomLeftLat == null || _bottomLeftLng == null) {
      debugPrint('Cannot save bounding box: coordinates not set');
      return;
    }
    
    try {
      await SupabaseService.saveBoundingBox(
        pointALat: _topLeftLat!,
        pointALng: _topLeftLng!,
        pointBLat: _topRightLat!,
        pointBLng: _topRightLng!,
        pointCLat: _bottomLeftLat!,
        pointCLng: _bottomLeftLng!,
        pointDLat: _bottomRightLat!,
        pointDLng: _bottomRightLng!,
        safeZoneId: safeZoneId,
        locationName: locationName,
      );
      
      debugPrint('Bounding box saved to database with safe zone ID: $safeZoneId');
    } catch (e) {
      debugPrint('Failed to save bounding box: $e');
    }
  }
}

class _BoundingBoxWidgetState extends State<BoundingBoxWidget> {
  bool _isDraggingDot = false;
  int _draggedCornerIndex = -1; // -1 means no corner, 0-3 means a specific corner
  Offset? _lastPosition;

  @override
  Widget build(BuildContext context) {
    // If pan is disabled, return an empty positioned widget that doesn't respond to gestures
    if (!widget.isPanEnabled) {
      return const Positioned.fill(
        child: SizedBox(), // Empty widget that doesn't respond to gestures
      );
    }
    
    // Only return the gesture detector when pan is enabled
    return Positioned.fill(
      child: GestureDetector(
        // Set behavior to translucent so it doesn't block other widgets' touch events
        behavior: HitTestBehavior.translucent,
        // Detect when touch starts
        onPanStart: (details) async {
          if (widget.mapController == null) return;
          
          // Check if we're touching near any of the dots
          final cornerIndex = await _checkNearCorner(widget.mapController!, details.localPosition);
          if (cornerIndex >= 0) {
            setState(() {
              _isDraggingDot = true;
              _draggedCornerIndex = cornerIndex;
              _lastPosition = details.localPosition;
              BoundingBoxWidget.setDraggingState(true, cornerIndex);
            });
            
            // Update dot appearance immediately
            await BoundingBoxWidget._updateDots(widget.mapController!);
          }
        },
        
        // Update position during drag
        onPanUpdate: (details) async {
          if (!_isDraggingDot || widget.mapController == null || _lastPosition == null) return;
          
          // Convert screen position to map coordinates
          final screenCoord = mp.ScreenCoordinate(
            x: details.localPosition.dx,
            y: details.localPosition.dy
          );
          
          final mapCoord = await widget.mapController!.coordinateForPixel(screenCoord);
          final lat = (mapCoord.coordinates[1] as num).toDouble();
          final lng = (mapCoord.coordinates[0] as num).toDouble();
          
          // Update the position based on which corner is being dragged
          await BoundingBoxWidget.updateCornerPosition(
            widget.mapController!,
            _draggedCornerIndex,
            lat,
            lng
          );
          
          _lastPosition = details.localPosition;
        },
        
        // End dragging
        onPanEnd: (details) async {
          if (_isDraggingDot && widget.mapController != null) {
            setState(() {
              _isDraggingDot = false;
              BoundingBoxWidget.setDraggingState(false, _draggedCornerIndex);
              _draggedCornerIndex = -1;
            });
            
            // Update dot appearance
            await BoundingBoxWidget._updateDots(widget.mapController!);
          }
        },
        
        // Make the gesture detector transparent to allow map interaction when not dragging
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }
  
  // Check if touching near any corner dot
  Future<int> _checkNearCorner(mp.MapboxMap mapController, Offset position) async {
    const corners = [
      {'name': 'topLeft', 'index': 0},
      {'name': 'topRight', 'index': 1},
      {'name': 'bottomRight', 'index': 2},
      {'name': 'bottomLeft', 'index': 3},
    ];
    
    for (final corner in corners) {
      final isNearCorner = await BoundingBoxWidget.isNearCorner(
        mapController, 
        position,
        corner['index'] as int
      );
      
      if (isNearCorner) {
        return corner['index'] as int;
      }
    }
    
    return -1; // No corner found near touch
  }
}