import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

class PathService {
  // Remove hardcoded coordinates and make them dynamic
  static double? sourceLatitude;
  static double? sourceLongitude;
  static double? destinationLatitude;
  static double? destinationLongitude;
  static String? sourceLocationName;
  static String? destinationLocationName;
  
  // Color definitions for the three routes
  static const int primaryRouteColor = 0xFF0000FF;     // Blue
  static const int secondaryRouteColor = 0xFFFFFF00;   // Yellow
  static const int tertiaryRouteColor = 0xFFFF0000;    // Red
  
  static mp.PolylineAnnotationManager? _lineManager;
  static mp.CircleAnnotationManager? _circleManager;

  // New method to set route coordinates
  static void setRouteCoordinates({
    required double sourceLat, 
    required double sourceLng,
    required double destLat,
    required double destLng,
    String? sourceName,
    String? destName,
  }) {
    sourceLatitude = sourceLat;
    sourceLongitude = sourceLng;
    destinationLatitude = destLat;
    destinationLongitude = destLng;
    sourceLocationName = sourceName;
    destinationLocationName = destName;

    debugPrint('Route coordinates set: From ($sourceLat,$sourceLng) to ($destLat,$destLng)');
  }

  // Check if coordinates are set and valid
  static bool hasValidCoordinates() {
    return sourceLatitude != null && 
           sourceLongitude != null && 
           destinationLatitude != null && 
           destinationLongitude != null;
  }

  static Future<void> displayPath(mp.MapboxMap? mapboxMapController) async {
    if (mapboxMapController == null) return;
    
    // Check if we have valid coordinates
    if (!hasValidCoordinates()) {
      debugPrint('No valid coordinates to display path');
      return;
    }
    
    // Cleanup any existing lines
    if (_lineManager != null) {
      await _lineManager!.deleteAll();
    } else {
      _lineManager = await mapboxMapController.annotations.createPolylineAnnotationManager();
    }
    
    // Cleanup any existing circles
    if (_circleManager != null) {
      await _circleManager!.deleteAll();
    } else {
      _circleManager = await mapboxMapController.annotations.createCircleAnnotationManager();
    }

    // Fetch routes from Google Directions API
    final routes = await fetchGoogleRoutes();
    if (routes.isEmpty) {
      debugPrint('No routes found to display');
      return;
    }
    
    // Display routes with different colors
    final colors = [primaryRouteColor, secondaryRouteColor, tertiaryRouteColor];

    final routesToDisplay = routes.length > 3 ? routes.sublist(0, 3) : routes;
    
    for (int i = 0; i < routesToDisplay.length; i++) {
      final route = routesToDisplay[i];
      final color = colors[i % colors.length];
      
      // Get coordinates from the route polyline
      final originalCoordinates = decodePolyline(route['polyline']).map((point) {
        return mp.Position(point[1], point[0]);
      }).toList();
      
      // Interpolate more points for denser dots
      final densifiedCoordinates = _densifyRoute(originalCoordinates, 5.0); // 5 meters between points

      // dont remove this comment it is for future reference
      // Skip creating and displaying polylines but keep the circle markers
      // final lineOptions = mp.PolylineAnnotationOptions(
      //   geometry: mp.LineString(coordinates: coordinates),
      //   lineWidth: 5.0,
      //   lineColor: color,
      //   lineOpacity: 0.8,
      //   lineJoin: mp.LineJoin.ROUND,
      //   // lineCap: mp.LineCap.ROUND,
      // );
      
      // Add the line to the map
      // await _lineManager!.create(lineOptions);
      
      debugPrint('Route ${i + 1} displayed with ${densifiedCoordinates.length} points (original: ${originalCoordinates.length})');
      
      // Add a colored dot (circle) for each densified coordinate
      for (final pos in densifiedCoordinates) {
        final circleOptions = mp.CircleAnnotationOptions(
          geometry: mp.Point(coordinates: pos),
          circleRadius: 3.0, // Smaller radius since we have more dots
          circleColor: color,
          circleOpacity: 0.8,
        );
        await _circleManager!.create(circleOptions);
      }
      
      debugPrint('Route ${i + 1} displayed with ${densifiedCoordinates.length} points (original: ${originalCoordinates.length})');
    }
    
    // Fit the map view to include all route coordinates
    if (routesToDisplay.isNotEmpty) {
      final bounds = mp.CoordinateBounds(
        southwest: mp.Point(coordinates: mp.Position(sourceLongitude!, sourceLatitude!)),
        northeast: mp.Point(coordinates: mp.Position(destinationLongitude!, destinationLatitude!)),
        infiniteBounds: false
      );
      
      final cameraOptions = mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            (sourceLongitude! + destinationLongitude!) / 2,
            (sourceLatitude! + destinationLatitude!) / 2
          )
        ),
        padding: mp.MbxEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
        zoom: 15.0
      );
      
      mapboxMapController.flyTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: 1000)
      );
    }
  }

  // Public method to clear the path
  static Future<void> clearPath(mp.MapboxMap? mapboxMapController) async {
    if (mapboxMapController == null) return;
    
    // Cleanup any existing circles
    if (_circleManager != null) {
      await _circleManager!.deleteAll();
    }
    
    // Cleanup any existing lines
    if (_lineManager != null) {
      await _lineManager!.deleteAll();
    }
    
    debugPrint('Route path cleared from map');
  }

  // Helper methods unchanged
  static List<mp.Position> _densifyRoute(List<mp.Position> originalPoints, double intervalMeters) {
    if (originalPoints.length < 2) return originalPoints;
    
    List<mp.Position> densifiedPoints = [];
    
    for (int i = 0; i < originalPoints.length - 1; i++) {
      final start = originalPoints[i];
      final end = originalPoints[i + 1];
      
      // Add the start point
      densifiedPoints.add(start);
      
      // Calculate distance between start and end points
      final distance = _calculateDistanceBetweenPoints(start, end);
      
      // Calculate how many intermediate points we need
      final numIntermediatePoints = (distance / intervalMeters).floor();
      
      // Add intermediate points
      for (int j = 1; j <= numIntermediatePoints; j++) {
        final ratio = j / (numIntermediatePoints + 1);
        final interpolatedPoint = _interpolatePosition(start, end, ratio);
        densifiedPoints.add(interpolatedPoint);
      }
    }
    
    // Add the final point
    densifiedPoints.add(originalPoints.last);
    
    return densifiedPoints;
  }

  static double _calculateDistanceBetweenPoints(mp.Position start, mp.Position end) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = start.lat * (math.pi / 180);
    final lat2Rad = end.lat * (math.pi / 180);
    final deltaLatRad = (end.lat - start.lat) * (math.pi / 180);
    final deltaLngRad = (end.lng - start.lng) * (math.pi / 180);
    
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static mp.Position _interpolatePosition(mp.Position start, mp.Position end, double ratio) {
    final lat = start.lat + (end.lat - start.lat) * ratio;
    final lng = start.lng + (end.lng - start.lng) * ratio;
    return mp.Position(lng, lat);
  }

  static Future<List<Map<String, dynamic>>> fetchGoogleRoutes() async {
    List<Map<String, dynamic>> routes = [];
    
    // Make sure we have valid coordinates
    if (!hasValidCoordinates()) {
      debugPrint('Cannot fetch routes: coordinates not set');
      return routes;
    }
    
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
      
      if (apiKey == null) {
        debugPrint('Error: Google API key not found in .env file');
        return routes;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$sourceLatitude,$sourceLongitude'
        '&destination=$destinationLatitude,$destinationLongitude'
        '&alternatives=true'
        '&mode=walking'  // Always use walking mode
        '&key=$apiKey'
      );

      debugPrint('Fetching routes from Google Directions API...');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK') {
          final routesData = data['routes'] as List;
          final routeCount = routesData.length;
          
          debugPrint('Found $routeCount routes from Google Directions API');
          
          for (int i = 0; i < routesData.length; i++) {
            final route = routesData[i];
            final legs = route['legs'] as List;
            
            if (legs.isNotEmpty) {
              final firstLeg = legs[0];
              final distance = firstLeg['distance']['text'];
              final duration = firstLeg['duration']['text'];
              
              debugPrint('Route ${i + 1}: Distance: $distance, Duration: $duration');
              
              routes.add({
                'distance': distance,
                'duration': duration,
                'polyline': route['overview_polyline']['points'],
                'route_index': i,
              });
            }
          }
        } else {
          debugPrint('Google Directions API error: ${data['status']}');
        }
      } else {
        debugPrint('Failed to fetch routes: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
      
      return routes;
    } catch (e) {
      debugPrint('Error fetching Google routes: $e');
      return routes;
    }
  }
  
  // Decode Google polyline format into list of [lat, lng] coordinates
  static List<List<double>> decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }
    return points;
  }
}