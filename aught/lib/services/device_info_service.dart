import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final deviceInfoPlugin = DeviceInfoPlugin();
  
  // Get device name based on platform
  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        
        // Just use model name without brand
        String deviceName = androidInfo.model;
        
        // Debug all available device info
        debugPrint('Android device details:');
        debugPrint('- Brand: ${androidInfo.brand}');
        debugPrint('- Device: ${androidInfo.device}');
        debugPrint('- Model: ${androidInfo.model}');
        debugPrint('- Product: ${androidInfo.product}');
        debugPrint('- Manufacturer: ${androidInfo.manufacturer}');
        
        return deviceName;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        // For iOS, we use the device name set by user
        debugPrint('iOS device name: ${iosInfo.name}');
        return iosInfo.name;
      }
      return 'Unknown Device';
    } catch (e) {
      debugPrint('Error getting device name: $e');
      return 'Unknown Device';
    }
  }

  // Get device ID that can be used to identify the device
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        
        // Try to get more meaningful identifiers
        String deviceId = androidInfo.id; // Default fallback
        
        // Debug all available device identifiers
        debugPrint('Android device IDs:');
        debugPrint('- ID: ${androidInfo.id}');
        debugPrint('- Serial: ${androidInfo.serialNumber}');
        debugPrint('- Fingerprint: ${androidInfo.fingerprint}');
        // androidId is not available in the current version, using id instead
        
        // If serial number is available and not empty/unknown, use it
        if (androidInfo.serialNumber.isNotEmpty && 
            androidInfo.serialNumber != 'unknown' && 
            androidInfo.serialNumber != '0') {
          deviceId = androidInfo.serialNumber;
        }
        
        return deviceId;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        // identifierForVendor is unique to the app vendor
        debugPrint('iOS device ID: ${iosInfo.identifierForVendor ?? "unknown"}');
        return iosInfo.identifierForVendor ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown';
    }
  }
}