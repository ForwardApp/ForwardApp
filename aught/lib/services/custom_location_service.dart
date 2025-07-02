import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_marker_service.dart';
import 'supabase_service.dart';
import 'device_location.dart';
import 'notification_service.dart';

// Helper class to track animation state - moved outside of CustomLocationService
class _MarkerAnimation {
  final int index;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final DateTime startTime;
  Timer? timer;
  
  _MarkerAnimation({
    required this.index,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  }) : startTime = DateTime.now();
  
  void dispose() {
    timer?.cancel();
    timer = null;
  }
}

class CustomLocationService {
  static List<mp.PointAnnotationManager?> _customPointAnnotationManagers = [];
  static List<mp.PointAnnotation?> _customImageAnnotations = [];
  static List<mp.CircleAnnotationManager?> _customPulseCircleManagers = [];
  static List<mp.CircleAnnotation?> _customPulseCircles = [];
  static RealtimeChannel? _realtimeSubscription;
  static mp.MapboxMap? _mapController;
  static AnimationController? _pulseController;
  static Map<int, int> _deviceIdToIndexMap = {};
  
  // Animation-related fields
  static Map<int, _MarkerAnimation> _markerAnimations = {};
  static const Duration _animationDuration = Duration(seconds: 10);

  static Future<void> addCustomImageAnnotations(mp.MapboxMap? mapboxMapController, AnimationController pulseController) async {
    if (mapboxMapController == null) return;

    _mapController = mapboxMapController;
    _pulseController = pulseController;

    _customPointAnnotationManagers.clear();
    _customImageAnnotations.clear();
    _customPulseCircleManagers.clear();
    _customPulseCircles.clear();
    _deviceIdToIndexMap.clear();
    _markerAnimations.clear();

    await _loadConnectedDevices();
    _setupRealtimeSubscription();
  }

  static Future<void> _loadConnectedDevices() async {
    try {
      final deviceCode = await DeviceLocation.getFormattedDeviceId();
      
      final myDeviceInfo = await SupabaseService.client
        .from('device_locations')
        .select('id')
        .eq('generated_id', deviceCode.replaceAll('-', ''))
        .single();
      
      final myDeviceId = myDeviceInfo['id'];
      
      final connectedDevices = await SupabaseService.client
        .from('connected_devices')
        .select('connected_device_id')
        .eq('device_location_id', myDeviceId);
      
      debugPrint('Found ${connectedDevices.length} connected devices');
      
      for (final device in connectedDevices) {
        final connectedDeviceId = device['connected_device_id'];
        
        final deviceLocation = await SupabaseService.client
          .from('device_locations')
          .select('latitude, longitude, device_name, tracking_active')
          .eq('id', connectedDeviceId)
          .single();
        
        if (deviceLocation['tracking_active'] == true) {
          final lat = deviceLocation['latitude']?.toDouble();
          final lng = deviceLocation['longitude']?.toDouble();
          final deviceName = deviceLocation['device_name'] ?? 'Unknown Device';
          
          if (lat != null && lng != null) {
            await _createMarkerForDevice(
              _mapController!, 
              lat, 
              lng, 
              deviceName,
              connectedDeviceId
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading connected devices: $e');
    }
  }

  static void _setupRealtimeSubscription() {
    try {
      _realtimeSubscription?.unsubscribe();
      
      _realtimeSubscription = SupabaseService.client
          .channel('device_locations_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'device_locations',
            callback: (payload) {
              debugPrint('Received real-time update: ${payload.newRecord}');
              _handleDeviceLocationUpdate(payload.newRecord);
            },
          )
          .subscribe();
      
      debugPrint('Real-time subscription setup for device locations');
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  static void _handleDeviceLocationUpdate(Map<String, dynamic> newRecord) async {
    try {
      final deviceId = newRecord['id'];
      final lat = newRecord['latitude']?.toDouble();
      final lng = newRecord['longitude']?.toDouble();
      final trackingActive = newRecord['tracking_active'];
      final deviceName = newRecord['device_name'] ?? 'Unknown Device';
      
      if (lat == null || lng == null || trackingActive != true) return;
      
      final index = _deviceIdToIndexMap[deviceId];
      
      if (index != null && 
          index < _customImageAnnotations.length && 
          _customImageAnnotations[index] != null) {
        
        // Get current position for animation
        final currentAnnotation = _customImageAnnotations[index]!;
        final currentGeometry = currentAnnotation.geometry;
        final currentLat = currentGeometry.coordinates.lat.toDouble();
        final currentLng = currentGeometry.coordinates.lng.toDouble();
        
        // Start smooth animation to new position
        _startMarkerAnimation(
          deviceId: deviceId,
          index: index,
          startLat: currentLat,
          startLng: currentLng,
          endLat: lat,
          endLng: lng,
        );
        
        // Check location against safe zones and send notifications
        await NotificationService.checkDeviceLocationAgainstSafeZones(
          deviceId: deviceId,
          latitude: lat,
          longitude: lng,
          deviceName: deviceName,
        );
      }
    } catch (e) {
      debugPrint('Error handling device location update: $e');
    }
  }
  
  static void _startMarkerAnimation({
    required int deviceId,
    required int index,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    // Cancel any existing animation for this device
    _markerAnimations[deviceId]?.dispose();
    
    // Create new animation state
    final animation = _MarkerAnimation(
      index: index,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    
    _markerAnimations[deviceId] = animation;
    
    // Update at approximately 30fps (33ms) for smooth animation
    // but without excessive performance impact
    animation.timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      final elapsedTime = DateTime.now().difference(animation.startTime);
      
      if (elapsedTime >= _animationDuration) {
        // Animation completed, set final position
        _updateMarkerPosition(index, endLat, endLng);
        
        // Clean up
        _markerAnimations[deviceId]?.dispose();
        _markerAnimations.remove(deviceId);
        timer.cancel();
        return;
      }
      
      // Calculate progress with easing (ease-out cubic)
      final progress = elapsedTime.inMilliseconds / _animationDuration.inMilliseconds;
      final easedProgress = _easeOutCubic(progress);
      
      // Interpolate position
      final currentLat = animation.startLat + (animation.endLat - animation.startLat) * easedProgress;
      final currentLng = animation.startLng + (animation.endLng - animation.startLng) * easedProgress;
      
      // Update marker position
      _updateMarkerPosition(index, currentLat, currentLng);
    });
  }
  
  // Cubic ease out function: decelerating to zero velocity
  static double _easeOutCubic(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
  }
  
  // Update marker position without animation
  static void _updateMarkerPosition(int index, double lat, double lng) async {
    try {
      final newPosition = mp.Point(coordinates: mp.Position(lng, lat));
      
      _customImageAnnotations[index]!.geometry = newPosition;
      await _customPointAnnotationManagers[index]!.update(_customImageAnnotations[index]!);
      
      _customPulseCircles[index]!.geometry = newPosition;
      await _customPulseCircleManagers[index]!.update(_customPulseCircles[index]!);
    } catch (e) {
      debugPrint('Error updating marker position: $e');
    }
  }

  static Future<void> _createMarkerForDevice(
    mp.MapboxMap mapboxMapController,
    double lat,
    double lng,
    String deviceName,
    int deviceId
  ) async {
    try {
      final pulseCircleManager = await mapboxMapController.annotations.createCircleAnnotationManager();
      _customPulseCircleManagers.add(pulseCircleManager);
      
      final pulseCircleOptions = mp.CircleAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(lng, lat),
        ),
        circleRadius: 15.0,
        circleColor: 0xFF007AFF,
        circleOpacity: 0.7,
        circleStrokeWidth: 0,
      );
      
      final pulseCircle = await pulseCircleManager.create(pulseCircleOptions);
      _customPulseCircles.add(pulseCircle);

      // Create point annotation manager
      final pointAnnotationManager = await mapboxMapController.annotations.createPointAnnotationManager();
      _customPointAnnotationManagers.add(pointAnnotationManager);

      final Uint8List imageData = await ImageMarkerService.createCircularMarker(
        assetPath: "lib/assets/CompanyLogo.jpg", // i like this image like this so dont change it at all
        size: 600,
      );

      final pointAnnotationOptions = mp.PointAnnotationOptions(
        image: imageData,
        iconSize: 0.3,
        geometry: mp.Point(
          coordinates: mp.Position(lng, lat),
        ),
      );

      final imageAnnotation = await pointAnnotationManager.create(pointAnnotationOptions);
      _customImageAnnotations.add(imageAnnotation);
      
      _deviceIdToIndexMap[deviceId] = _customImageAnnotations.length - 1;

      debugPrint('Custom image annotation created for $deviceName at: $lat, $lng (index: ${_customImageAnnotations.length - 1})');
    } catch (e) {
      debugPrint('Error creating marker for device $deviceName: $e');
    }
  }

  static void updateCustomPulseEffect(AnimationController pulseController) {
    try {
      final animationValue = pulseController.value;
      final baseRadius = 15.0;
      final maxRadius = 45.0;  
      
      final currentRadius = baseRadius + (maxRadius - baseRadius) * animationValue;
      final currentOpacity = 1.0 - animationValue;
      
      for (int i = 0; i < _customPulseCircles.length; i++) {
        if (_customPulseCircles[i] != null && _customPulseCircleManagers[i] != null) {
          _customPulseCircles[i]!.circleRadius = currentRadius;
          _customPulseCircles[i]!.circleOpacity = currentOpacity;
          _customPulseCircles[i]!.circleColor = 0xFF007AFF;
          
          _customPulseCircleManagers[i]!.update(_customPulseCircles[i]!);
        }
      }
    } catch (e) {
      debugPrint('Error updating custom pulse effect: $e');
    }
  }

  static Future<void> checkCustomZoomAndUpdateVisibility(mp.MapboxMap? mapboxMapController) async {
    if (mapboxMapController == null) return;

    try {
      final cameraState = await mapboxMapController.getCameraState();
      final currentZoom = cameraState.zoom;

      for (int i = 0; i < _customImageAnnotations.length; i++) {
        if (_customImageAnnotations[i] != null && _customPointAnnotationManagers[i] != null) {
          if (currentZoom < 9.0) {
            if (_customImageAnnotations[i]!.iconOpacity != 0.0) {
              _customImageAnnotations[i]!.iconOpacity = 0.0;
              await _customPointAnnotationManagers[i]!.update(_customImageAnnotations[i]!);
            }
          } else {
            if (_customImageAnnotations[i]!.iconOpacity != 1.0) {
              _customImageAnnotations[i]!.iconOpacity = 1.0;
              await _customPointAnnotationManagers[i]!.update(_customImageAnnotations[i]!);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking custom zoom and updating visibility: $e');
    }
  }

  static Future<void> removeDeviceAnnotation(int deviceId) async {
    final index = _deviceIdToIndexMap[deviceId];
    
    if (index != null && 
        index < _customImageAnnotations.length &&
        index < _customPulseCircles.length) {
      
      try {
        // Remove point annotation
        if (_customPointAnnotationManagers[index] != null &&
            _customImageAnnotations[index] != null) {
          await _customPointAnnotationManagers[index]!.delete(_customImageAnnotations[index]!);
          _customImageAnnotations[index] = null;
        }
        
        // Remove pulse circle
        if (_customPulseCircleManagers[index] != null &&
            _customPulseCircles[index] != null) {
          await _customPulseCircleManagers[index]!.delete(_customPulseCircles[index]!);
          _customPulseCircles[index] = null;
        }
        
        // Cancel any active animation
        _markerAnimations[deviceId]?.dispose();
        _markerAnimations.remove(deviceId);
        
        // Remove from device ID mapping
        _deviceIdToIndexMap.remove(deviceId);
        
        debugPrint('Removed annotations for device ID: $deviceId');
      } catch (e) {
        debugPrint('Error removing device annotation: $e');
      }
    }
  }

  static void dispose() {
    // Cancel all active animations
    for (final animation in _markerAnimations.values) {
      animation.dispose();
    }
    _markerAnimations.clear();
    
    // Clear notification statuses for all tracked devices
    for (final deviceId in _deviceIdToIndexMap.keys) {
      NotificationService.clearDeviceStatus(deviceId);
    }
    
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = null;
    _customPointAnnotationManagers.clear();
    _customImageAnnotations.clear();
    _customPulseCircleManagers.clear();
    _customPulseCircles.clear();
    _deviceIdToIndexMap.clear();
    _mapController = null;
    _pulseController = null;
  }
}