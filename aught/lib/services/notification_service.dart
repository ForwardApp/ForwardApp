import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math' as math;
import 'supabase_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track device states to avoid duplicate notifications
  static Map<int, bool> _deviceInSafeZoneStatus = {};
  static Map<int, String> _deviceNames = {};
  static Map<int, DateTime> _deviceLastChangeTime = {};
  static const int _minimumChangeInterval = 30;
  static const double _toleranceMeters = 10.0;

  // Background notification tracking
  static bool _isInBackground = false;
  static DateTime? _lastBackgroundNotificationTime;
  static const int _backgroundNotificationCooldown = 60; // 1 minute cooldown

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    
    await _createNotificationChannel();
    await _createBackgroundNotificationChannel();
    await _requestNotificationPermission();
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'safe_zone_alerts',
      'Safe Zone Alerts',
      description: 'Notifications for safe zone entry and exit',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      debugPrint('Safe zone notification channel created');
    }
  }

  static Future<void> _createBackgroundNotificationChannel() async {
    const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
      'background_alerts',
      'Background Alerts',
      description: 'Notifications for background app state',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(backgroundChannel);
      debugPrint('Background notification channel created');
    }
  }

  static Future<void> _requestNotificationPermission() async {
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('Notification permission granted: $granted');
    }
  }

  // Method to handle app lifecycle changes
  static Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_isInBackground) {
          _isInBackground = true;
          await _showBackgroundNotification();
        }
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        // Cancel the background notification when app returns to foreground
        await _notificationsPlugin.cancel(999);
        // Reset the last notification time so we'll show a notification immediately next time
        _lastBackgroundNotificationTime = null;
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        if (!_isInBackground) {
          _isInBackground = true;
          await _showBackgroundNotification();
        }
        break;
    }
  }

  static Future<void> _showBackgroundNotification() async {
    final now = DateTime.now();
    
    // Check cooldown to prevent spam notifications
    if (_lastBackgroundNotificationTime != null) {
      final timeSinceLastNotification = now.difference(_lastBackgroundNotificationTime!).inSeconds;
      if (timeSinceLastNotification < _backgroundNotificationCooldown) {
        debugPrint('Background notification skipped - cooldown active');
        return;
      }
    }
    
    _lastBackgroundNotificationTime = now;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'background_alerts',
      'Background Alerts',
      channelDescription: 'Notifications for background app state',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
      ongoing: true, 
      autoCancel: false, 
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final List<String> backgroundMessages = [
      'We are tracking in the background',
      'Location services running in background',
      'Background monitoring active',
      'Keeping you safe in the background',
      'Background location tracking enabled',
      'We are working behind the scenes',
      'Background services are active',
    ];

    final randomMessage = backgroundMessages[math.Random().nextInt(backgroundMessages.length)];

    await _notificationsPlugin.show(
      999,
      'App Running in Background',
      randomMessage,
      platformChannelSpecifics,
    );

    debugPrint('Background notification sent: $randomMessage');
  }

  // Main method to check device location against all bounding boxes
  static Future<void> checkDeviceLocationAgainstSafeZones({
    required int deviceId,
    required double latitude,
    required double longitude,
    required String deviceName,
  }) async {
    try {
      _deviceNames[deviceId] = deviceName;

      final boundingBoxes = await SupabaseService.getBoundingBoxes();
      
      bool isInAnySafeZone = false;
      String? currentSafeZoneName;

      for (final box in boundingBoxes) {
        bool isInThisZone = _isPointInBoundingBoxWithTolerance(
          latitude: latitude,
          longitude: longitude,
          boundingBox: box,
        );
        
        debugPrint('Device $deviceName at ($latitude, $longitude) - Zone ${box['location_name']}: ${isInThisZone ? 'INSIDE' : 'OUTSIDE'}');
        
        if (isInThisZone) {
          isInAnySafeZone = true;
          currentSafeZoneName = box['location_name'] ?? 'Safe Zone';
          break;
        }
      }

      final wasInSafeZone = _deviceInSafeZoneStatus[deviceId] ?? false;
      
      if (isInAnySafeZone != wasInSafeZone) {
        final lastChangeTime = _deviceLastChangeTime[deviceId] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final now = DateTime.now();
        
        if (now.difference(lastChangeTime).inSeconds >= _minimumChangeInterval) {
          _deviceInSafeZoneStatus[deviceId] = isInAnySafeZone;
          _deviceLastChangeTime[deviceId] = now;
          
          if (isInAnySafeZone) {
            debugPrint('NOTIFICATION: $deviceName ENTERED $currentSafeZoneName');
            await _showSafeZoneEntryNotification(deviceName, currentSafeZoneName!);
            await _saveNotificationToDatabase(
              deviceId: deviceId,
              status: 'entered',
              locationName: currentSafeZoneName,
              details: '$deviceName has entered the safe zone: $currentSafeZoneName',
            );
          } else {
            debugPrint('NOTIFICATION: $deviceName EXITED safe zone');
            await _showSafeZoneExitNotification(deviceName);
            await _saveNotificationToDatabase(
              deviceId: deviceId,
              status: 'exited',
              details: '$deviceName has left all safe zones',
            );
          }
        } else {
          debugPrint('Status change ignored - too soon (${now.difference(lastChangeTime).inSeconds}s < ${_minimumChangeInterval}s)');
        }
      } else {
        debugPrint('No status change for $deviceName - staying ${isInAnySafeZone ? 'INSIDE' : 'OUTSIDE'}');
      }
    } catch (e) {
      debugPrint('Error checking device location against safe zones: $e');
    }
  }

  // Check if a point is inside a bounding box polygon using ray casting algorithm
  static bool _isPointInBoundingBox({
    required double latitude,
    required double longitude,
    required Map<String, dynamic> boundingBox,
  }) {
    try {
      final List<Map<String, double>> polygon = [
        {'lat': boundingBox['point_a_lat'].toDouble(), 'lng': boundingBox['point_a_lng'].toDouble()},
        {'lat': boundingBox['point_b_lat'].toDouble(), 'lng': boundingBox['point_b_lng'].toDouble()},
        {'lat': boundingBox['point_c_lat'].toDouble(), 'lng': boundingBox['point_c_lng'].toDouble()},
        {'lat': boundingBox['point_d_lat'].toDouble(), 'lng': boundingBox['point_d_lng'].toDouble()},
      ];

      debugPrint('Checking point ($latitude, $longitude) against polygon:');
      for (int i = 0; i < polygon.length; i++) {
        debugPrint('  Point ${String.fromCharCode(65 + i)}: (${polygon[i]['lat']}, ${polygon[i]['lng']})');
      }

      bool result = _pointInPolygon(latitude, longitude, polygon);
      debugPrint('Point-in-polygon result: $result');
      
      return result;
    } catch (e) {
      debugPrint('Error checking point in bounding box: $e');
      return false;
    }
  }

  // Ray casting algorithm to determine if point is inside polygon
  static bool _pointInPolygon(double lat, double lng, List<Map<String, double>> polygon) {
  int intersectCount = 0;
  int n = polygon.length;
  
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    
    double lat1 = polygon[i]['lat']!;
    double lng1 = polygon[i]['lng']!;
    double lat2 = polygon[j]['lat']!;
    double lng2 = polygon[j]['lng']!;
    
    // Make sure lat1 <= lat2
    if (lat1 > lat2) {
      double tempLat = lat1;
      double tempLng = lng1;
      lat1 = lat2;
      lng1 = lng2;
      lat2 = tempLat;
      lng2 = tempLat;
    }
    
    // Check if point is on the same horizontal line as the edge
    if (lat == lat1 || lat == lat2) {
      lat += 0.0000001; // Slightly adjust to avoid edge cases
    }
    
    // Check if the ray crosses this edge
    if ((lat1 < lat && lat <= lat2) || (lat2 < lat && lat <= lat1)) {
      // Calculate intersection point
      double intersectionLng = lng1 + (lat - lat1) / (lat2 - lat1) * (lng2 - lng1);
      
      if (lng < intersectionLng) {
        intersectCount++;
      }
    }
  }
  
  return (intersectCount % 2) == 1;
}

  static bool _isPointInBoundingBoxWithTolerance({
    required double latitude,
    required double longitude,
    required Map<String, dynamic> boundingBox,
  }) {
    try {
      final List<Map<String, double>> originalPolygon = [
        {'lat': boundingBox['point_a_lat'].toDouble(), 'lng': boundingBox['point_a_lng'].toDouble()},
        {'lat': boundingBox['point_b_lat'].toDouble(), 'lng': boundingBox['point_b_lng'].toDouble()},
        {'lat': boundingBox['point_c_lat'].toDouble(), 'lng': boundingBox['point_c_lng'].toDouble()},
        {'lat': boundingBox['point_d_lat'].toDouble(), 'lng': boundingBox['point_d_lng'].toDouble()},
      ];

      final centerLat = originalPolygon.map((p) => p['lat']!).reduce((a, b) => a + b) / 4;
      final centerLng = originalPolygon.map((p) => p['lng']!).reduce((a, b) => a + b) / 4;
      const double metersToDegreesLat = 111320.0;
      const double toleranceDegrees = _toleranceMeters / metersToDegreesLat;

      final List<Map<String, double>> expandedPolygon = originalPolygon.map((point) {
        final lat = point['lat']!;
        final lng = point['lng']!;
        
        final latDirection = lat > centerLat ? 1 : -1;
        final lngDirection = lng > centerLng ? 1 : -1;
        
        return {
          'lat': lat + (toleranceDegrees * latDirection),
          'lng': lng + (toleranceDegrees * lngDirection),
        };
      }).toList();

      bool isInOriginal = _pointInPolygon(latitude, longitude, originalPolygon);
      bool isInExpanded = _pointInPolygon(latitude, longitude, expandedPolygon);

      if (isInOriginal) {
        debugPrint('Point is clearly inside original polygon');
        return true;
      } else if (isInExpanded) {
        debugPrint('Point is in tolerance zone - checking distance to edges');
        
        double minDistance = double.infinity;
        for (int i = 0; i < originalPolygon.length; i++) {
          int j = (i + 1) % originalPolygon.length;
          double distance = _distanceToLineSegment(
            latitude, longitude,
            originalPolygon[i]['lat']!, originalPolygon[i]['lng']!,
            originalPolygon[j]['lat']!, originalPolygon[j]['lng']!,
          );
          if (distance < minDistance) {
            minDistance = distance;
          }
        }
        
        bool isWithinTolerance = minDistance <= _toleranceMeters;
        debugPrint('Minimum distance to polygon edge: ${minDistance.toStringAsFixed(2)}m, within tolerance: $isWithinTolerance');
        return isWithinTolerance;
      } else {
        debugPrint('Point is clearly outside polygon');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking point in bounding box with tolerance: $e');
      return false;
    }
  }

  static double _distanceToLineSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    const double earthRadius = 6371000.0;
    
    final double lat1Rad = x1 * (math.pi / 180);
    final double lon1Rad = y1 * (math.pi / 180);
    final double lat2Rad = x2 * (math.pi / 180);
    final double lon2Rad = y2 * (math.pi / 180);
    final double latPRad = px * (math.pi / 180);
    final double lonPRad = py * (math.pi / 180);

    final double A = latPRad - lat1Rad;
    final double B = lonPRad - lon1Rad;
    final double C = lat2Rad - lat1Rad;
    final double D = lon2Rad - lon1Rad;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;
    
    if (lenSq == 0) {
      final double dLat = latPRad - lat1Rad;
      final double dLon = lonPRad - lon1Rad;
      return earthRadius * math.sqrt(dLat * dLat + dLon * dLon);
    }

    final double param = dot / lenSq;
    
    double closestLat, closestLon;
    if (param < 0) {
      closestLat = lat1Rad;
      closestLon = lon1Rad;
    } else if (param > 1) {
      closestLat = lat2Rad;
      closestLon = lon2Rad;
    } else {
      closestLat = lat1Rad + param * C;
      closestLon = lon1Rad + param * D;
    }

    final double dLat = latPRad - closestLat;
    final double dLon = lonPRad - closestLon;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latPRad) * math.cos(closestLat) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static Future<void> _showSafeZoneEntryNotification(String deviceName, String safeZoneName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'safe_zone_alerts',
      'Safe Zone Alerts',
      channelDescription: 'Notifications for safe zone entry and exit',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50), // Green color for entry
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      deviceName.hashCode, // Use device name hash as unique ID
      'Safe Zone Entry',
      '$deviceName has entered $safeZoneName',
      platformChannelSpecifics,
    );

    debugPrint('Safe zone entry notification sent for $deviceName');
  }

  static Future<void> _showSafeZoneExitNotification(String deviceName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'safe_zone_alerts',
      'Safe Zone Alerts',
      channelDescription: 'Notifications for safe zone entry and exit',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFF44336), // Red color for exit
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      deviceName.hashCode, // Use device name hash as unique ID
      'Safe Zone Exit',
      '$deviceName has left the safe zone',
      platformChannelSpecifics,
    );

    debugPrint('Safe zone exit notification sent for $deviceName');
  }

  // Save notification to database for history
  static Future<void> _saveNotificationToDatabase({
    required int deviceId,
    required String status,
    String? locationName,
    String? details,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        await SupabaseService.initialize();
      }

      await SupabaseService.client.from('notifications').insert({
        'device_location_id': deviceId,
        'status': status,
        'location_name': locationName,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Notification saved to database: $status for device $deviceId');
    } catch (e) {
      debugPrint('Error saving notification to database: $e');
    }
  }

  // Get notification history from database
  static Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      if (!SupabaseService.isInitialized) {
        await SupabaseService.initialize();
      }

      final response = await SupabaseService.client
          .from('notifications')
          .select('*, device_locations(device_name)')
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notification history: $e');
      return [];
    }
  }

  // Clear device status (useful when device stops tracking)
  static void clearDeviceStatus(int deviceId) {
    _deviceInSafeZoneStatus.remove(deviceId);
    _deviceNames.remove(deviceId);
    _deviceLastChangeTime.remove(deviceId);
    debugPrint('Cleared status for device $deviceId');
  }

  // Get current status of all tracked devices
  static Map<int, bool> getDeviceStatuses() {
    return Map.from(_deviceInSafeZoneStatus);
  }

  // Method to manually trigger a test notification
  static Future<void> showTestNotification() async {
    await _showSafeZoneEntryNotification('Test Device', 'Test Safe Zone');
  }
}