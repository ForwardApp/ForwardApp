import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_location.dart';
import 'supabase_service.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  bool _isTrackingEnabled = false;
  bool get isTrackingEnabled => _isTrackingEnabled;
  
  // Using ChangeNotifier pattern to allow widgets to listen for changes
  final ValueNotifier<bool> trackingStatus = ValueNotifier<bool>(false);

  // Initialize tracking state from database
  Future<void> initialize() async {
    try {
      // Make sure device code is loaded
      final deviceCode = await DeviceLocation.getFormattedDeviceId();

      // Make sure Supabase is initialized
      if (!SupabaseService.isInitialized) {
        await SupabaseService.initialize();
      }

      // If Supabase is initialized, check the device tracking status
      if (SupabaseService.isInitialized) {
        final response = await SupabaseService.client
            .from('device_locations')
            .select('tracking_active')
            .eq('generated_id', deviceCode.replaceAll('-', ''))
            .maybeSingle();

        _isTrackingEnabled = response != null && response['tracking_active'] == true;
        trackingStatus.value = _isTrackingEnabled;

        // If tracking is enabled in DB but not active in service, restart it
        if (_isTrackingEnabled) {
          DeviceLocation.startTracking(deviceCode.replaceAll('-', ''));
        }
      }
    } catch (e) {
      debugPrint('Error initializing tracking service: $e');
    }
  }

  // Set tracking state and persist to database
  Future<void> setTracking(bool value) async {
    try {
      _isTrackingEnabled = value;
      trackingStatus.value = value;
      
      // Get device code
      final deviceCode = await DeviceLocation.getFormattedDeviceId();
      
      if (value) {
        // Start tracking - connect device ID to database
        try {
          if (!SupabaseService.isInitialized) {
            await SupabaseService.initialize();
          }
          
          // Get actual device name and hardware ID
          final deviceName = await DeviceLocation.getDeviceName();
          final deviceHardwareId = await DeviceLocation.getDeviceHardwareId();
          
          // First check if the device already exists in database
          final response = await SupabaseService.client
              .from('device_locations')
              .select()
              .eq('generated_id', deviceCode.replaceAll('-', ''))
              .maybeSingle();
          
          if (response == null) {
            // Add new device entry if it doesn't exist
            await SupabaseService.client.from('device_locations').insert({
              'device_id': deviceHardwareId,
              'device_name': deviceName,
              'generated_id': deviceCode.replaceAll('-', ''),
              'latitude': 0.0,  // Will be updated with real location
              'longitude': 0.0, // Will be updated with real location
              'tracking_active': true,  // Set to true when toggle is on
              'timestamp': DateTime.now().toIso8601String()
            });
            
            debugPrint('Added new device to database with generated ID: $deviceCode');
          } else {
            // Just update the timestamp and device info for existing device
            await SupabaseService.client
                .from('device_locations')
                .update({
                  'timestamp': DateTime.now().toIso8601String(),
                  'tracking_active': true,  // Set to true when toggle is on
                  'device_id': deviceHardwareId,
                  'device_name': deviceName
                })
                .eq('generated_id', deviceCode.replaceAll('-', ''));
                
            debugPrint('Updated existing device tracking status');
          }
          
          // Start location tracking service
          DeviceLocation.startTracking(deviceCode.replaceAll('-', ''));
        } catch (e) {
          debugPrint('Error connecting device to database: $e');
        }
      } else {
        // Stop tracking
        DeviceLocation.stopTracking();
        
        // Update device status in database to indicate tracking is stopped
        try {
          if (SupabaseService.isInitialized) {
            await SupabaseService.client
                .from('device_locations')
                .update({
                  'tracking_active': false,
                  'timestamp': DateTime.now().toIso8601String()
                })
                .eq('generated_id', deviceCode.replaceAll('-', ''));
            
            debugPrint('Device tracking disabled in database for ID: $deviceCode');
          }
        } catch (e) {
          debugPrint('Error updating device tracking status: $e');
        }
      }
    } catch (e) {
      debugPrint('Error setting tracking state: $e');
    }
  }
}