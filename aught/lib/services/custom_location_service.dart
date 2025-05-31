import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_marker_service.dart';
import 'supabase_service.dart';
import 'device_location.dart';

class CustomLocationService {
  static List<mp.PointAnnotationManager?> _customPointAnnotationManagers = [];
  static List<mp.PointAnnotation?> _customImageAnnotations = [];
  static List<mp.CircleAnnotationManager?> _customPulseCircleManagers = [];
  static List<mp.CircleAnnotation?> _customPulseCircles = [];
  static RealtimeChannel? _realtimeSubscription;
  static mp.MapboxMap? _mapController;
  static AnimationController? _pulseController;
  static Map<int, int> _deviceIdToIndexMap = {};

  static Future<void> addCustomImageAnnotations(mp.MapboxMap? mapboxMapController, AnimationController pulseController) async {
    if (mapboxMapController == null) return;

    _mapController = mapboxMapController;
    _pulseController = pulseController;

    _customPointAnnotationManagers.clear();
    _customImageAnnotations.clear();
    _customPulseCircleManagers.clear();
    _customPulseCircles.clear();
    _deviceIdToIndexMap.clear();

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
      
      if (lat == null || lng == null || trackingActive != true) return;
      
      final index = _deviceIdToIndexMap[deviceId];
      
      if (index != null && 
          index < _customImageAnnotations.length && 
          _customImageAnnotations[index] != null &&
          index < _customPointAnnotationManagers.length &&
          _customPointAnnotationManagers[index] != null &&
          index < _customPulseCircles.length &&
          _customPulseCircles[index] != null &&
          index < _customPulseCircleManagers.length &&
          _customPulseCircleManagers[index] != null) {
        
        final newPosition = mp.Point(coordinates: mp.Position(lng, lat));
        
        _customImageAnnotations[index]!.geometry = newPosition;
        await _customPointAnnotationManagers[index]!.update(_customImageAnnotations[index]!);
        
        _customPulseCircles[index]!.geometry = newPosition;
        await _customPulseCircleManagers[index]!.update(_customPulseCircles[index]!);
        
        debugPrint('Updated marker position for device $deviceId to: $lat, $lng');
      }
    } catch (e) {
      debugPrint('Error handling device location update: $e');
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

  static void dispose() {
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