import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'device_location.dart';
import 'supabase_service.dart';

class BackgroundLocationService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    // Get device ID for database updates
    final deviceCode = await DeviceLocation.getFormattedDeviceId();
    final cleanDeviceId = deviceCode.replaceAll('-', '');
    
    // Listen for location updates
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Location Tracking",
          content: "Lat: ${position.latitude}, Long: ${position.longitude}",
        );
      }
      
      try {
        // Update location in database like in device_location.dart
        if (SupabaseService.isInitialized) {
          await SupabaseService.client
              .from('device_locations')
              .update({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'timestamp': DateTime.now().toIso8601String()
              })
              .eq('generated_id', cleanDeviceId);
          
          debugPrint('Background location updated: ${position.latitude}, ${position.longitude}');
        }
      } catch (e) {
        debugPrint('Error updating location from background service: $e');
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static void startBackgroundTracking() {
    FlutterBackgroundService().startService();
  }

  static void stopBackgroundTracking() {
    FlutterBackgroundService().invoke('stopService');
  }
}