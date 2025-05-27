// I am using Mapbox Maps Flutter SDK version 2.8.0.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import '../widgets/location_button.dart';
import '../widgets/directions_button.dart';
import '../widgets/safehome_button.dart';
import '../widgets/sidebar.dart';
import '../services/image_marker_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  bool _hasLocationPermission = false;
  bool _initialLocationRequested = false;
  bool _isSidebarOpen = false;
  late AnimationController _sidebarAnimationController;
  late Animation<Offset> _sidebarSlideAnimation;

  // Add these variables to track the annotation manager and annotation
  mp.PointAnnotationManager? _pointAnnotationManager;
  mp.PointAnnotation? _userImageAnnotation;
  Timer? _positionUpdateTimer;
  Timer? _zoomCheckTimer; // Add this new timer for zoom checking

  // Get current style URI based on time
  String _getCurrentStyleUri() {
    final now = DateTime.now();
    final hour = now.hour; // 0-23 format

    if (hour >= 7 && hour < 12) {
      // 7:00-11:59 - Day
      return "mapbox://styles/reggie88/cmb27dqr100ht01sd2vrmc4uy?fresh=true";
    } else if (hour >= 12 && hour < 17) {
      // 12:00-16:59 - Dawn
      return "mapbox://styles/reggie88/cmb28mvuo00h201r4g0s71ji2?fresh=true";
    } else if (hour >= 17 && hour < 20) {
      // 17:00-19:59 - Dusk
      return "mapbox://styles/reggie88/cmb28o5py00gs01scewx2d393?fresh=true";
    } else {
      // 20:00-6:59 - Night
      return "mapbox://styles/reggie88/cmb2hf23r00gv01qx1kra2j8j?fresh=true"; 
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize sidebar animation controller
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sidebarSlideAnimation =
        Tween<Offset>(
          begin: const Offset(-1.0, 0.0), // Start from left (off-screen)
          end: Offset.zero, // End at normal position
        ).animate(
          CurvedAnimation(
            parent: _sidebarAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    _positionUpdateTimer?.cancel();
    _zoomCheckTimer?.cancel(); // Add this line
    _sidebarAnimationController.dispose();
    // Clean up annotation resources
    _pointAnnotationManager = null;
    _userImageAnnotation = null;
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });

    if (_isSidebarOpen) {
      _sidebarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
    }
  }

  void _closeSidebar() {
    _sidebarAnimationController.reverse().then((_) {
      setState(() {
        _isSidebarOpen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map as the base layer
          mp.MapWidget(
            styleUri: _getCurrentStyleUri(), // Use time-based style
            onMapCreated: _onMapCreated,
          ),

          // Sidebar button in top left
          Positioned(
            left: 16,
            top: 50, // Adjusted for status bar
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.0),
                  onTap: _toggleSidebar,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black54, // Same gray color used by other icons
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'lib/assets/sidebarthick.jpg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Control buttons in bottom right
          Positioned(
            right: 16,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // My Location Button
                LocationButton(mapboxMapController: mapboxMapController),

                const SizedBox(height: 8),
                
                // Safe Home Button
                const SafeHomeButton(),
                
                const SizedBox(height: 8),

                // Directions Button
                const DirectionsButton(),
              ],
            ),
          ),

          // Sidebar overlay - always present but animated
          SlideTransition(
            position: _sidebarSlideAnimation,
            child: Sidebar(onClose: _closeSidebar),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });


    // Set camera bounds with maximum zoom limit
    await mapboxMapController?.setBounds(
      mp.CameraBoundsOptions(
        maxZoom: 19.0,
        // minZoom is not set, so users can zoom out freely
      ),
    );

    // Move logo and other UI elements first
    mapboxMapController?.logo.updateSettings(
      mp.LogoSettings(
        position: mp.OrnamentPosition.TOP_RIGHT,
        marginLeft: 1000,
        marginTop: 40,
        marginRight: 0,
        marginBottom: 10,
      ),
    );

    mapboxMapController?.attribution.updateSettings(
      mp.AttributionSettings(
        position: mp.OrnamentPosition.TOP_RIGHT,
        marginTop: 40,
        marginLeft: 1000,
        clickable: true,
      ),
    );

    mapboxMapController?.compass.updateSettings(
      mp.CompassSettings(
        position: mp.OrnamentPosition.TOP_RIGHT,
        marginRight: 16,
        marginTop: 50,
        enabled: true,
      ),
    );

    mapboxMapController?.scaleBar.updateSettings(
      mp.ScaleBarSettings(
        position: mp.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 16,
        marginBottom: 16,
        enabled: true,
      ),
    );

    // Check if we have location permission
    _hasLocationPermission = await _checkLocationPermission();

    if (_hasLocationPermission) {
      // Permission already granted - go directly to user location
      await _requestLocationAndCenter();
    } else {
      // No permission - set initial camera to maximum zoom out (world view)
      mapboxMapController?.setCamera(
        mp.CameraOptions(
          pitch: 0.0, // Flat view for world overview
          bearing: 0.0,
          zoom: 1.0, // Maximum zoom out
        ),
      );

      // Automatically trigger location request after showing world view
      if (!_initialLocationRequested) {
        _initialLocationRequested = true;
        // Small delay to ensure map is fully loaded
        await Future.delayed(const Duration(milliseconds: 500));
        await _requestLocationAndCenter();
      }
    }

    // Add image annotation at current location
    await _addImageAnnotation();
  }


  Future<void> _addImageAnnotation() async {
    if (mapboxMapController == null) return;

    try {
      // Get current location
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Create point annotation manager only once
      if (_pointAnnotationManager == null) {
        _pointAnnotationManager = await mapboxMapController?.annotations
            .createPointAnnotationManager();
      }

      // Load the circular image using the service
      final Uint8List imageData = await ImageMarkerService.createCircularMarker(
        assetPath: "lib/assets/andriii.jpg",
        size: 600,
      );

      // Create point annotation options with vertical offset
      final pointAnnotationOptions = mp.PointAnnotationOptions(
        image: imageData,
        iconSize: 0.3,
        iconOffset: [0.0, -50.0], // Move the image up by 50 pixels
        geometry: mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        ),
      );

      // Create the annotation and store reference
      _userImageAnnotation = await _pointAnnotationManager?.create(
        pointAnnotationOptions,
      );

      debugPrint(
        'Image annotation created at: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error adding image annotation: $e');
    }
  }

  // Add this new method to check zoom level and update visibility
  Future<void> _checkZoomAndUpdateVisibility() async {
    if (_pointAnnotationManager == null ||
        _userImageAnnotation == null ||
        mapboxMapController == null) {
      return;
    }

    try {
      // Get current camera state to check zoom level
      final cameraState = await mapboxMapController!.getCameraState();
      final currentZoom = cameraState.zoom;

      // Hide image annotation when zoomed out beyond ~1km scale (zoom level 12)
      // Show it when zoomed in closer than that
      if (currentZoom < 9.0) {
        // Zoomed out - hide the image annotation
        if (_userImageAnnotation!.iconOpacity != 0.0) {
          _userImageAnnotation!.iconOpacity = 0.0; // Make it invisible
          await _pointAnnotationManager!.update(_userImageAnnotation!);
          debugPrint('Image hidden at zoom: $currentZoom');
        }
      } else {
        // Zoomed in - show the image annotation
        if (_userImageAnnotation!.iconOpacity != 1.0) {
          _userImageAnnotation!.iconOpacity = 1.0; // Make it visible
          await _pointAnnotationManager!.update(_userImageAnnotation!);
          debugPrint('Image shown at zoom: $currentZoom');
        }
      }
    } catch (e) {
      debugPrint('Error checking zoom and updating visibility: $e');
    }
  }

  Future<void> _updateImageAnnotationPosition(gl.Position position) async {
    if (_pointAnnotationManager == null || _userImageAnnotation == null) {
      debugPrint('Cannot update annotation: manager or annotation is null');
      return;
    }

    try {
      // Update the annotation geometry directly (remove zoom check from here since it's handled by the timer)
      _userImageAnnotation!.geometry = mp.Point(
        coordinates: mp.Position(position.longitude, position.latitude),
      );

      // Ensure the offset is maintained when updating
      _userImageAnnotation!.iconOffset = [
        0.0,
        -100.0,
      ]; // Keep the image above the puck

      // Update the annotation on the map
      await _pointAnnotationManager!.update(_userImageAnnotation!);

      debugPrint(
        'Updated annotation position to: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error updating image annotation position: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    final permission = await gl.Geolocator.checkPermission();
    final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    return serviceEnabled &&
        (permission == gl.LocationPermission.whileInUse ||
            permission == gl.LocationPermission.always);
  }

  Future<void> _requestLocationAndCenter() async {
    if (mapboxMapController == null) return;

    try {
      // Check permission before trying to get location
      final permission = await gl.Geolocator.checkPermission();

      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        // Request permission - this will show Android permission dialog
        final newPermission = await gl.Geolocator.requestPermission();

        if (newPermission == gl.LocationPermission.denied ||
            newPermission == gl.LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          return;
        }
      }

      // Check if location services are enabled
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      // Permission granted - get location and animate
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.best, // Changed to best accuracy
      );

      // Update location component settings to keep the default blue/white puck
      await mapboxMapController!.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          puckBearingEnabled:
              false, // Enable bearing for more accurate tracking
          // Remove the locationPuck customization to keep the default blue/white puck
        ),
      );

      // Animate to user's location with same animation as location button
      mapboxMapController!.flyTo(
        mp.CameraOptions(
          pitch: 60.0,
          bearing: 0.0,
          zoom: 18.0,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
        mp.MapAnimationOptions(duration: 3000),
      );

      // Start position tracking AFTER the map has loaded and camera is set
      await Future.delayed(const Duration(milliseconds: 1000));
      _setupPositionTracking();

      setState(() {
        _hasLocationPermission = true;
      });
    } catch (e) {
      debugPrint('Error requesting location: $e');
    }
  }

  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Show dialog to user about enabling location services
      _showLocationServiceDialog();
      return false;
    }

    // Check current permission status
    permission = await gl.Geolocator.checkPermission();

    if (permission == gl.LocationPermission.denied) {
      // Request permission - this will show Android permission dialog
      permission = await gl.Geolocator.requestPermission();

      if (permission == gl.LocationPermission.denied) {
        // Permission denied by user
        _showPermissionDeniedDialog();
        return false;
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      // Permissions are permanently denied
      _showPermissionPermanentlyDeniedDialog();
      return false;
    }

    // Permission granted - animate to user's location
    if (permission == gl.LocationPermission.whileInUse ||
        permission == gl.LocationPermission.always) {
      _animateToUserLocation();
    }

    // Permission granted
    return true;
  }

  Future<void> _animateToUserLocation() async {
    try {
      // Get the user's current location
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Animate camera to user's location with the same animation as location button
      mapboxMapController?.flyTo(
        mp.CameraOptions(
          pitch: 60.0,
          bearing: 0.0,
          zoom: 18.0,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
        mp.MapAnimationOptions(duration: 3000), // Same 3-second animation
      );
    } catch (e) {
      debugPrint('Error animating to user location: $e');
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'This app needs location services to show your position on the map. Please enable location services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs location permission to show your position on the map. You can grant permission in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Try requesting permission again
                final hasPermission = await _requestLocationPermission();
                if (hasPermission) {
                  mapboxMapController?.location.updateSettings(
                    mp.LocationComponentSettings(
                      enabled: true,
                      pulsingEnabled: true,
                    ),
                  );
                  _setupPositionTracking();
                }
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permissions are permanently denied. Please enable them in your device settings to use location features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open app settings
                await gl.Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setupPositionTracking() async {
    gl.LocationSettings locationSettings = const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 1, // Reduced to 1 meter for very frequent updates
    );

    userPositionStream?.cancel();
    userPositionStream =
        gl.Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((gl.Position? position) {
          if (position != null && mapboxMapController != null) {
            debugPrint(
              'New position received: ${position.latitude}, ${position.longitude}',
            );

            // Keep only the image annotation position update
            _updateImageAnnotationPosition(position);
          }
        });

    // Also set up a more frequent timer to get current position
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      try {
        final position = await gl.Geolocator.getCurrentPosition(
          desiredAccuracy: gl.LocationAccuracy.high,
        );
        _updateImageAnnotationPosition(position);
      } catch (e) {
        debugPrint('Error getting current position: $e');
      }
    });

    // Add a timer specifically for checking zoom level changes
    _zoomCheckTimer?.cancel();
    _zoomCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      await _checkZoomAndUpdateVisibility();
    });

    debugPrint('Position tracking setup complete');
  }
}
