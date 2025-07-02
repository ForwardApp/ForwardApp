import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_location.dart';
import '../services/supabase_service.dart';
import '../services/tracking_service.dart';
import '../screens/map_screen.dart';
import '../services/custom_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Settingpage extends StatefulWidget {
  final VoidCallback onClose;

  const Settingpage({super.key, required this.onClose});

  @override
  State<Settingpage> createState() => _SettingpageState();
}

class _SettingpageState extends State<Settingpage> {
  bool _isTrackingEnabled = false;
  bool _isAccordionExpanded = false;
  late String _deviceCode;
  
  // Replace the mockup tracked devices with a Future to fetch real data
  Future<List<Map<String, dynamic>>>? _connectedDevicesFuture;

  RealtimeChannel? _deviceCodesSubscription;

  @override
  void initState() {
    super.initState();
    // Get the stored device code when the settings page is opened
    _loadDeviceCode();
    // Use the tracking service instead of directly checking status
    _loadTrackingStatus();
    // Load connected devices from database
    _loadConnectedDevices();
    _setupDeviceCodesSubscription();
  }
  
  // Load device code from persistent storage
  Future<void> _loadDeviceCode() async {
    final persistentCode = await DeviceLocation.getFormattedDeviceId();
    setState(() {
      _deviceCode = persistentCode;
    });
  }

  // Load tracking status from the TrackingService
  Future<void> _loadTrackingStatus() async {
    final trackingService = TrackingService();
    setState(() {
      _isTrackingEnabled = trackingService.isTrackingEnabled;
    });
    
    // Listen for changes in tracking status
    trackingService.trackingStatus.addListener(() {
      if (mounted) {
        setState(() {
          _isTrackingEnabled = trackingService.isTrackingEnabled;
        });
      }
    });
  }

  // Load connected devices from the database
  Future<void> _loadConnectedDevices() async {
    setState(() {
      _connectedDevicesFuture = _fetchConnectedDevices();
    });
  }

  // Fetch connected devices from Supabase
  Future<List<Map<String, dynamic>>> _fetchConnectedDevices() async {
    try {
      // First get our device ID
      final deviceCode = await DeviceLocation.getFormattedDeviceId();
      
      // Get my device info (ID) using the generated code
      final myDeviceInfo = await SupabaseService.client
        .from('device_locations')
        .select('id')
        .eq('generated_id', deviceCode.replaceAll('-', ''))
        .single();
      
      final myDeviceId = myDeviceInfo['id'];
      
      // Get all connected devices for my device
      final connectedDevices = await SupabaseService.client
        .from('connected_devices')
        .select('id, connected_device_id, connection_name, last_connected')
        .eq('device_location_id', myDeviceId);
        
      // Create a list to store the final device data
      final List<Map<String, dynamic>> deviceDataList = [];
      
      // For each connected device, get the device name
      for (final device in connectedDevices) {
        final connectedDeviceId = device['connected_device_id'];
        final connectionName = device['connection_name'];
        
        // Get device details from device_locations table
        final deviceDetails = await SupabaseService.client
          .from('device_locations')
          .select('device_name, tracking_active')
          .eq('id', connectedDeviceId)
          .single();
        
        deviceDataList.add({
          'id': device['id'],
          'name': connectionName ?? deviceDetails['device_name'] ?? 'Unknown Device',
          'isActive': deviceDetails['tracking_active'] ?? false,
          'lastConnected': device['last_connected'],
          'deviceName': deviceDetails['device_name'],
          'connectionName': connectionName,
          'connectedDeviceId': connectedDeviceId
        });
      }
      
      return deviceDataList;
    } catch (e) {
      debugPrint('Error fetching connected devices: $e');
      return [];
    }
  }

  void _showTrackDeviceModal() {
    // First show the dialog immediately
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String deviceCode = '';
        String errorMessage = '';
        
        // If accordion is expanded, close it in the background
        if (_isAccordionExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isAccordionExpanded = false;
            });
          });
        }
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Track a Device',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Enter the 6-digit code from the other device',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: '12A-4B6',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.text,
                        maxLength: 7,
                        buildCounter: (BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) => null, // Hide the counter
                        showCursor: false,
                        onChanged: (value) {
                          // Convert to uppercase
                          String uppercaseValue = value.toUpperCase();
                          if (uppercaseValue != value) {
                            // If there was a conversion, update the controller
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              TextEditingController controller = TextEditingController(text: uppercaseValue)
                                ..selection = TextSelection.fromPosition(TextPosition(offset: uppercaseValue.length));
                              setState(() {});
                            });
                          }
                          
                          String cleanedValue = uppercaseValue.replaceAll('-', '');
                          
                          // Check if the cleaned value (without dash) has more than 6 digits
                          if (cleanedValue.length > 6) {
                            // If already 6 digits, don't allow more input
                            return;
                          }
                          
                          if (cleanedValue.isNotEmpty && RegExp(r'^[A-Za-z0-9]+$').hasMatch(cleanedValue)) {
                            if (cleanedValue.length > 3) {
                              deviceCode = '${cleanedValue.substring(0, 3)}-${cleanedValue.substring(3, cleanedValue.length)}';
                            } else {
                              deviceCode = cleanedValue;
                            }
                            
                            setState(() {});
                          } else if (cleanedValue.isEmpty) {
                            deviceCode = '';
                            setState(() {});
                          }
                        },
                        controller: TextEditingController(text: deviceCode)
                          ..selection = TextSelection.fromPosition(TextPosition(offset: deviceCode.length)),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            // This prevents more than 6 digits total (excluding the dash)
                            String clean = newValue.text.replaceAll('-', '');
                            if (clean.length > 6) {
                              return oldValue;
                            }
                            return newValue;
                          }),
                        ],
                      ),
                    ),
                    
                    if (errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.grey),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              String cleanCode = deviceCode.replaceAll('-', '');
                              if (cleanCode.length != 6) {
                                return;
                              }
                              
                              try {
                                // Get my device info (the one connecting)
                                final myDeviceInfo = await SupabaseService.client
                                  .from('device_locations')
                                  .select('id, generated_id')
                                  .eq('generated_id', _deviceCode.replaceAll('-', ''))
                                  .single();
                                
                                final myDeviceId = myDeviceInfo['id'];
                                final myGeneratedId = myDeviceInfo['generated_id'];
                                
                                // Check if target device exists
                                final targetDeviceExists = await SupabaseService.client
                                  .from('device_locations')
                                  .select('id, generated_id')
                                  .eq('generated_id', cleanCode)
                                  .maybeSingle();
                                  
                                if (targetDeviceExists == null) {
                                  setState(() {
                                    errorMessage = 'The code provided does not exist';
                                  });
                                  return;
                                }

                                final targetDeviceId = targetDeviceExists['id'];
                                
                                // Check if connection already exists between these two devices
                                final existingConnection = await SupabaseService.client
                                  .from('connected_devices')
                                  .select()
                                  .eq('device_location_id', myDeviceId)
                                  .eq('connected_device_id', targetDeviceId)
                                  .maybeSingle();
                                  
                                if (existingConnection != null) {
                                  // Update existing connection with new generated_id
                                  await SupabaseService.client
                                    .from('connected_devices')
                                    .update({
                                      'generated_id': cleanCode,
                                      'last_connected': DateTime.now().toIso8601String()
                                    })
                                    .eq('id', existingConnection['id']);
                                } else {
                                  // Create new connection
                                  await SupabaseService.client
                                    .from('connected_devices')
                                    .insert({
                                      'device_location_id': myDeviceId,
                                      'generated_id': cleanCode,
                                      'connected_device_id': targetDeviceId,
                                      'last_connected': DateTime.now().toIso8601String(),
                                      'created_at': DateTime.now().toIso8601String()
                                    });
                                }
                                
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Device connected successfully'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  
                                  // Refresh the connected devices list in settings
                                  _loadConnectedDevices();
                                  
                                  // Refresh the map to show the newly connected device
                                  try {
                                    MapScreen.refreshCustomImageAnnotations();
                                  } catch (e) {
                                    debugPrint('Error refreshing map after device connection: $e');
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error connecting to device: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Connect',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _toggleTracking(bool value) async {
    // Use the tracking service to set tracking state
    final trackingService = TrackingService();
    await trackingService.setTracking(value);
    
    // No need to setState here as the listener will update it
  }

  // Method to refresh the device code
  Future<void> _refreshDeviceCode() async {
    try {
      // Get old device code for database update
      final oldDeviceId = _deviceCode.replaceAll('-', '');
      
      // Generate new device code
      final newDeviceCode = DeviceLocation.generateDeviceId();
      
      setState(() {
        _deviceCode = newDeviceCode;
      });
      
      // Save the new device code to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DeviceLocation.deviceIdKey, newDeviceCode);
      
      // Update the device ID in the database if tracking is enabled
      if (_isTrackingEnabled && SupabaseService.isInitialized) {
        await SupabaseService.client
          .from('device_locations')
          .update({
            'generated_id': newDeviceCode.replaceAll('-', ''),
            'timestamp': DateTime.now().toIso8601String()
          })
          .eq('generated_id', oldDeviceId);
        
        // Restart location tracking with new device ID
        DeviceLocation.stopTracking();
        DeviceLocation.startTracking(newDeviceCode.replaceAll('-', ''));
        
        debugPrint('Device ID updated from $oldDeviceId to ${newDeviceCode.replaceAll('-', '')}');
      }
    } catch (e) {
      debugPrint('Error refreshing device code: $e');
    }
  }

  void _showEditDeviceNameModal(Map<String, dynamic> device) {
    TextEditingController nameController = TextEditingController();
    
    // If there's already a connection_name, pre-fill it
    if (device['connectionName'] != null) {
      nameController.text = device['connectionName'];
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Edit Device Name',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Put any name you want',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty) {
                            // Update connection name in database
                            try {
                              await SupabaseService.client
                                .from('connected_devices')
                                .update({
                                  'connection_name': newName,
                                })
                                .eq('id', device['id']);
                                
                              // Refresh the list
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                _loadConnectedDevices();
                              }
                            } catch (e) {
                              debugPrint('Error updating connection name: $e');
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update device name'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.black),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to clear the connection name
  void _clearConnectionName(Map<String, dynamic> device) async {
    try {
      // Update the database to set connection_name to null
      await SupabaseService.client
        .from('connected_devices')
        .update({
          'connection_name': null,
        })
        .eq('id', device['id']);
      
      // Refresh the devices list
      _loadConnectedDevices();
      
      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom name removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing connection name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove name'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Add this method to watch for code changes in tracked devices
  void _setupDeviceCodesSubscription() async {
    try {
      // Get my device ID to know which connections to monitor
      final deviceCode = await DeviceLocation.getFormattedDeviceId();
      
      // Get my device info using the generated code
      final myDeviceInfo = await SupabaseService.client
        .from('device_locations')
        .select('id')
        .eq('generated_id', deviceCode.replaceAll('-', ''))
        .single();
      
      final myDeviceId = myDeviceInfo['id'];
      
      // Get all connected devices and their current generated IDs
      final connectedDevices = await SupabaseService.client
        .from('connected_devices')
        .select('id, connected_device_id, generated_id')
        .eq('device_location_id', myDeviceId);
      
      // Create a map to track the current generated IDs
      Map<int, String> trackedDeviceIds = {};
      for (final device in connectedDevices) {
        trackedDeviceIds[device['connected_device_id']] = device['generated_id'];
      }
      
      debugPrint('Tracking generated IDs for ${trackedDeviceIds.length} devices');
      
      // Cancel any existing subscription
      _deviceCodesSubscription?.unsubscribe();
      
      // Subscribe to device_locations changes
      _deviceCodesSubscription = SupabaseService.client
        .channel('device_codes_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'device_locations',
          callback: (payload) async {
            final updatedDeviceId = payload.newRecord['id'];
            final newGeneratedId = payload.newRecord['generated_id'];
            
            // Check if this is a device we're tracking
            if (trackedDeviceIds.containsKey(updatedDeviceId)) {
              final oldGeneratedId = trackedDeviceIds[updatedDeviceId];
              
              // Only react if the generated_id has actually changed
              if (oldGeneratedId != newGeneratedId) {
                debugPrint('Tracked device changed its code: $oldGeneratedId → $newGeneratedId');
                
                final existingConnection = await SupabaseService.client
                  .from('connected_devices')
                  .select('id')
                  .eq('device_location_id', myDeviceId)
                  .eq('connected_device_id', updatedDeviceId)
                  .maybeSingle();
                
                if (existingConnection != null) {
                  // Delete the connection from database
                  await SupabaseService.client
                    .from('connected_devices')
                    .delete()
                    .eq('id', existingConnection['id']);
                  
                  // Update our local tracking map
                  trackedDeviceIds.remove(updatedDeviceId);
                  
                  // Refresh the connected devices list
                  if (mounted) {
                    _loadConnectedDevices();
                    
                    // Remove the marker from the map
                    MapScreen.removeCustomImageAnnotation(updatedDeviceId);
                    
                    // Show notification to user
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A tracked device has changed its code and is no longer visible'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } else {
                debugPrint('Tracked device updated but code did not change');
              }
            }
          },
        )
        .subscribe();
        
      debugPrint('Device codes subscription set up successfully');
    } catch (e) {
      debugPrint('Error setting up device codes subscription: $e');
    }
  }

  @override
  void dispose() {
    _deviceCodesSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black54,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tracking This Device',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      Switch(
                        value: _isTrackingEnabled,
                        onChanged: _toggleTracking,
                        activeColor: Colors.black,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  
                  if (_isTrackingEnabled) ...[
                    const SizedBox(height: 20),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The centered text
                          Center(
                            child: Text(
                              _deviceCode,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          // The refresh icon positioned on the right
                          Positioned(
                            right: 0,
                            child: GestureDetector(
                              onTap: _refreshDeviceCode,
                              child: const Icon(
                                Icons.refresh,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],
                  
                  GestureDetector(
                    onTap: _showTrackDeviceModal,
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Track a Device',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black54,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAccordionExpanded = !_isAccordionExpanded;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tracked Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          Icon(
                            _isAccordionExpanded 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down,
                            color: Colors.black54,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _isAccordionExpanded ? null : 0,
                    child: ClipRect(
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        heightFactor: _isAccordionExpanded ? 1.0 : 0.0,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _connectedDevicesFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: Colors.black),
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasError) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Could not load connected devices',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                
                                final devices = snapshot.data ?? [];
                                
                                if (devices.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No connected devices found',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14.0,
                                      ),
                                    ),
                                  );
                                }
                                
                                return Column(
                                  children: devices.map((device) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.smartphone,
                                            color: Colors.black54,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text(
                                                  device['name'] ?? 'Unknown Device',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Edit icon with tap functionality
                                                GestureDetector(
                                                  onTap: () {
                                                    _showEditDeviceNameModal(device);
                                                  },
                                                  child: const Icon(
                                                    Icons.edit,
                                                    color: Colors.grey,
                                                    size: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Green dot for active status
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: device['isActive'] ? Colors.green : Colors.grey,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          // Clear name icon - moved next to green dot
                                          if (device['connectionName'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  _clearConnectionName(device);
                                                },
                                                child: const Icon(
                                                  Icons.clear_rounded,
                                                  color: Colors.grey,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }
}