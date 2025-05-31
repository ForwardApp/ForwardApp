import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'device_info_service.dart';

class DeviceLocation {
  static final Random _random = Random();
  static Timer? _locationUpdateTimer;
  static String? _currentDeviceId;
  static String? _deviceName;
  static String? _deviceHardwareId;
  static const String deviceIdKey = 'device_location_id'; // Key for storing device ID in SharedPreferences
  
  // Initialize the device name and hardware ID
  static Future<void> initializeDeviceInfo() async {
    try {
      debugPrint('Getting device name and ID...');
      _deviceName = await DeviceInfoService.getDeviceName();
      _deviceHardwareId = await DeviceInfoService.getDeviceId();
      debugPrint('Device initialized: $_deviceName (ID: $_deviceHardwareId)');
      
      // Store these values in shared preferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', _deviceName ?? 'Unknown Device');
      await prefs.setString('device_hardware_id', _deviceHardwareId ?? 'unknown');
      debugPrint('Device info saved to preferences');
    } catch (e) {
      debugPrint('Error initializing device info: $e');
      // Try to load from preferences as fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        _deviceName = prefs.getString('device_name') ?? 'Unknown Device';
        _deviceHardwareId = prefs.getString('device_hardware_id') ?? 'unknown';
        debugPrint('Loaded device info from preferences: $_deviceName (ID: $_deviceHardwareId)');
      } catch (e2) {
        debugPrint('Error loading device info from preferences: $e2');
      }
    }
  }
  
  // Generate a new random device ID with 4 numbers and 2 letters in random positions
  // Format: XXX-XXX (with dash in the middle)
  static String generateDeviceId() {
    // Create a list of 6 characters (4 numbers and 2 letters)
    List<String> characters = [];
    
    // Add 4 random numbers
    for (int i = 0; i < 4; i++) {
      characters.add(_random.nextInt(10).toString());
    }
    
    // Add 2 random uppercase letters
    for (int i = 0; i < 2; i++) {
      // ASCII: 65 = 'A', 90 = 'Z'
      characters.add(String.fromCharCode(65 + _random.nextInt(26)));
    }
    
    // Shuffle the characters to randomize position of numbers and letters
    characters.shuffle(_random);
    
    // Insert dash in the middle (after 3rd character)
    String firstPart = characters.sublist(0, 3).join('');
    String secondPart = characters.sublist(3).join('');
    
    return '$firstPart-$secondPart';
  }
  
  // Get formatted device ID for display - loads from storage or generates new one
  static Future<String> getFormattedDeviceId() async {
    // Try to get existing device ID from local storage first
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(deviceIdKey);
    
    // If no ID stored, generate new one and save it
    if (storedId == null) {
      storedId = generateDeviceId();
      await prefs.setString(deviceIdKey, storedId);
      debugPrint('Generated and saved new device ID: $storedId');
    } else {
      debugPrint('Using stored device ID: $storedId');
    }
    
    return storedId;
  }
  
  // Start tracking device location and update database
  static void startTracking(String deviceId) async {
    _currentDeviceId = deviceId;
    
    // Initialize device info if not already done
    if (_deviceName == null || _deviceHardwareId == null) {
      await initializeDeviceInfo();
    }
    
    // Cancel existing timer if any
    _locationUpdateTimer?.cancel();
    
    // Start a timer to update location periodically
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services are disabled');
          return;
        }
        
        // Check location permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('Location permission denied');
            return;
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          debugPrint('Location permission permanently denied');
          return;
        }
        
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        
        // Update position in database for this device ID
        if (SupabaseService.isInitialized) {
          await SupabaseService.client
              .from('device_locations')
              .update({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'timestamp': DateTime.now().toIso8601String(),
                'device_name': _deviceName ?? 'Unknown Device',
                'device_id': _deviceHardwareId ?? 'unknown'
              })
              .eq('generated_id', deviceId);
          
          debugPrint('Updated device location: ${position.latitude}, ${position.longitude}');
        }
      } catch (e) {
        debugPrint('Error updating location: $e');
      }
    });
    
    debugPrint('Started location tracking for device: $deviceId');
  }
  
  // Stop tracking device location
  static void stopTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _currentDeviceId = null;
    debugPrint('Stopped location tracking');
  }
  
  // Get the actual device name
  static Future<String> getDeviceName() async {
    if (_deviceName == null) {
      await initializeDeviceInfo();
    }
    return _deviceName ?? 'Unknown Device';
  }
  
  // Get the hardware ID of the device
  static Future<String> getDeviceHardwareId() async {
    if (_deviceHardwareId == null) {
      await initializeDeviceInfo();
    }
    return _deviceHardwareId ?? 'unknown';
  }
}