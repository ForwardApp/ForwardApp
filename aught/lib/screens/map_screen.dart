// I am using Mapbox Maps Flutter SDK version 2.8.0.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import '../widgets/location_button.dart';
import '../widgets/directions_button.dart';
import '../widgets/safehome_button.dart';
import '../widgets/sidebar.dart';
import '../services/image_marker_service.dart';
import '../services/custom_location_service.dart';
import '../widgets/bounding_box.dart';
import '../widgets/safe_zone_toolbar.dart';
import '../services/supabase_service.dart';
import '../services/path_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static _MapScreenState? _instance;
  
static void flyToLocation(double latitude, double longitude, String locationName, {int? safeZoneId}) {
    if (_instance != null && _instance!.mapboxMapController != null) {
      _instance!.flyToSafeZone(latitude, longitude, locationName, safeZoneId: safeZoneId);
    }
  }

  // Make sure this static method is in the MapScreen class
  static void navigateToRoute(
    double sourceLat, 
    double sourceLng, 
    double destLat, 
    double destLng, 
    {String? sourceName, String? destName}
  ) {
    debugPrint('MapScreen.navigateToRoute called with: ($sourceLat, $sourceLng) to ($destLat, $destLng)');
    if (_instance != null && _instance!.mapboxMapController != null) {
      _instance!.enterNavigationMode(
        sourceLat, 
        sourceLng, 
        destLat, 
        destLng,
        sourceName: sourceName,
        destName: destName
      );
    } else {
      debugPrint('Error: MapScreen instance or mapboxMapController is null');
    }
  }
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  bool _hasLocationPermission = false;
  bool _initialLocationRequested = false;
  bool _isSidebarOpen = false;
  bool _isInSafeZoneMode = false;
  bool _isPanDisabled = false; // Pan is enabled by default
  
  // Fields to store current safe zone data
  int? _currentSafeZoneId;
  String? _currentSafeZoneName;
  
  // Navigation mode fields
  bool _isInNavigationMode = false;
  String? _navigationSourceName;
  String? _navigationDestName;
  
  late AnimationController _sidebarAnimationController;
  late Animation<Offset> _sidebarSlideAnimation;

  // Add these variables to your class state
  late AnimationController _pulseAnimationController;
  mp.CircleAnnotationManager? _pulseCircleManager;
  mp.CircleAnnotation? _pulseCircle;

  mp.PointAnnotationManager? _pointAnnotationManager;
  mp.PointAnnotation? _userImageAnnotation;
  mp.PointAnnotationManager? _greenDotManager;
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
    MapScreen._instance = this;
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
    
    // Initialize pulse animation controller
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Add listener to update pulse animation
    _pulseAnimationController.addListener(_updatePulseEffect);
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    _positionUpdateTimer?.cancel();
    _zoomCheckTimer?.cancel();
    _sidebarAnimationController.dispose();
    _pulseAnimationController.dispose();
    // Clean up annotation resources
    _pointAnnotationManager = null;
    _userImageAnnotation = null;
    _pulseCircleManager = null;
    CustomLocationService.dispose();
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
          mp.MapWidget(
            key: ValueKey(_getCurrentStyleUri()),
            styleUri: _getCurrentStyleUri(),
            cameraOptions: mp.CameraOptions(
              center: mp.Point(coordinates: mp.Position(0, 0)),
              zoom: 1.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Show exit navigation button only when in navigation mode
          if (_isInNavigationMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: _exitNavigationMode,
                  tooltip: 'Exit navigation',
                ),
              ),
            ),

          // Show navigation info when in navigation mode
          if (_isInNavigationMode && _navigationSourceName != null && _navigationDestName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: TextField(
                            enabled: false,
                            controller: TextEditingController(text: _navigationSourceName ?? ''),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black54),
                            onPressed: _exitNavigationMode,
                            tooltip: 'Exit navigation',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: TextField(
                            enabled: false,
                            controller: TextEditingController(text: _navigationDestName ?? ''),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: const Icon(Icons.swap_vert, color: Colors.black54),
                            onPressed: () {},
                            tooltip: 'Swap locations',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Add BoundingBoxWidget first (lower z-index)
          if (_isInSafeZoneMode && mapboxMapController != null)
            BoundingBoxWidget(
              mapController: mapboxMapController,
              isPanEnabled: !_isPanDisabled,
            ),
            
          // Then add UI elements that need to be interactive (higher z-index)
          if (!_isInSafeZoneMode) ...[
            Positioned(
              bottom: 30,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocationButton(mapboxMapController: mapboxMapController),
                  if (!_isInNavigationMode) ...[
                    const SizedBox(height: 10),
                    DirectionsButton(),
                    const SizedBox(height: 10),
                    SafeHomeButton(),
                  ],
                ],
              ),
            ),

            if (!_isInNavigationMode)
              Positioned(
                top: 50,
                left: 20,
                child: GestureDetector(
                  onTap: _toggleSidebar,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'lib/assets/sidebarthick.jpg',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        color: Colors.grey[600],
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
          ] else ...[
            Positioned(
              right: 10,
              top: MediaQuery.of(context).size.height / 2 - 140,
              child: SafeZoneToolbar(
                initialPanDisabled: _isPanDisabled,
                onPanToggled: (isPanDisabled) {
                  setState(() {
                    _isPanDisabled = isPanDisabled;
                  });
                },
                onMapToggled: _handleMapToggle,
                onClosePressed: _exitSafeZoneMode,
                onSavePressed: _saveAndExitSafeZoneInPlace,
              ),
            ),
          ],

          if (_isSidebarOpen && !_isInSafeZoneMode && !_isInNavigationMode)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          if (_isSidebarOpen && !_isInSafeZoneMode && !_isInNavigationMode)
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
    

    await CustomLocationService.addCustomImageAnnotations(mapboxMapController, _pulseAnimationController);
    
    // Load and display saved bounding boxes from database
    await _loadAndDisplayBoundingBoxes();
    
    // Display the path between the predefined points in Finland
    await PathService.displayPath(mapboxMapController);
  }

  // Add method to load and display bounding boxes from database
  Future<void> _loadAndDisplayBoundingBoxes() async {
    try {
      // Fetch bounding boxes from database
      final boundingBoxes = await SupabaseService.getBoundingBoxes();
      
      if (boundingBoxes.isEmpty) {
        debugPrint('No bounding boxes found in database');
        return;
      }
      
      debugPrint('Loaded ${boundingBoxes.length} bounding boxes from database');
      
      // Create polygon manager if needed
      if (_polygonManager == null && mapboxMapController != null) {
        _polygonManager = await mapboxMapController!.annotations.createPolygonAnnotationManager();
      } else if (_polygonManager != null) {
        // Clear all existing polygons first to prevent stacking
        await _polygonManager!.deleteAll();
      }
      
      // Create line manager if needed for borders
      if (_lineManager == null && mapboxMapController != null) {
        _lineManager = await mapboxMapController!.annotations.createPolylineAnnotationManager();
      } else if (_lineManager != null) {
        // Clear all existing lines first
        await _lineManager!.deleteAll();
      }
      
      // Display each bounding box on the map
      for (final box in boundingBoxes) {
        await _displayBoundingBox(box);
      }
    } catch (e) {
      debugPrint('Error loading bounding boxes: $e');
    }
  }
  
  // Add polygon manager
  mp.PolygonAnnotationManager? _polygonManager;
  // Add polyline manager for thick borders
  mp.PolylineAnnotationManager? _lineManager;
  
  // Display a single bounding box on the map
  Future<void> _displayBoundingBox(Map<String, dynamic> boxData) async {
    if (mapboxMapController == null || _polygonManager == null) return;
    
    try {
      // Create the polygon fill
      final polygonOptions = mp.PolygonAnnotationOptions(
        geometry: mp.Polygon(
          coordinates: [
            [
              mp.Position(boxData['point_a_lng'], boxData['point_a_lat']), // Top left
              mp.Position(boxData['point_b_lng'], boxData['point_b_lat']), // Top right
              mp.Position(boxData['point_d_lng'], boxData['point_d_lat']), // Bottom right
              mp.Position(boxData['point_c_lng'], boxData['point_c_lat']), // Bottom left
              mp.Position(boxData['point_a_lng'], boxData['point_a_lat']), // Close the polygon
            ]
          ],
        ),
        fillColor: 0x6000FF00, // Semi-transparent green fill
        fillOpacity: 0.6,
      );
      
      await _polygonManager!.create(polygonOptions);
      
      // Now create a line annotation for the border
      if (_lineManager == null && mapboxMapController != null) {
        _lineManager = await mapboxMapController!.annotations.createPolylineAnnotationManager();
      }
      
      // Create a thick red border as a separate line annotation
      final lineOptions = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(
          coordinates: [
            mp.Position(boxData['point_a_lng']- 0.0000025, boxData['point_a_lat']), // Top left
            mp.Position(boxData['point_b_lng'], boxData['point_b_lat']), // Top right
            mp.Position(boxData['point_d_lng'], boxData['point_d_lat']), // Bottom right
            mp.Position(boxData['point_c_lng'], boxData['point_c_lat']), // Bottom left
            mp.Position(boxData['point_a_lng'], boxData['point_a_lat']), // Close the polygon
          ],
        ),
        lineColor: 0xFFFF0000, // Solid red color
        lineWidth: 4.0, // Thick line
      );
      
      await _lineManager!.create(lineOptions);
      
      final locationName = boxData['location_name'] ?? 'Unknown location';
      debugPrint('Displayed bounding box for $locationName on map');
    } catch (e) {
      debugPrint('Error displaying bounding box: $e');
    }
  }

  Future<void> _addImageAnnotation() async {
    if (mapboxMapController == null) return;

    try {
      // Get current location
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Create pulse circle manager if needed
      if (_pulseCircleManager == null) {
        _pulseCircleManager = await mapboxMapController?.annotations
            .createCircleAnnotationManager();
      }
      
      // Create pulse circle annotation options
      final pulseCircleOptions = mp.CircleAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        ),
        circleRadius: 15.0,
        circleColor: 0xFF007AFF, // Blue color
        circleOpacity: 0.7,
        circleStrokeWidth: 0, // No stroke
      );
      
      // Create pulse circle annotation FIRST
      _pulseCircle = await _pulseCircleManager?.create(pulseCircleOptions);

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

      // Create point annotation options (no vertical offset)
      final pointAnnotationOptions = mp.PointAnnotationOptions(
        image: imageData,
        iconSize: 0.3,
        geometry: mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        ),
      );

      // Create the image annotation SECOND (will be on top)
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
      
      // Also check custom location visibility
      await CustomLocationService.checkCustomZoomAndUpdateVisibility(mapboxMapController);
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
      // Update the annotation geometry directly
      _userImageAnnotation!.geometry = mp.Point(
        coordinates: mp.Position(position.longitude, position.latitude),
      );

      // Update the annotation on the map
      await _pointAnnotationManager!.update(_userImageAnnotation!);
      
      // Also update pulse circle position if it exists
      if (_pulseCircle != null && _pulseCircleManager != null) {
        _pulseCircle!.geometry = mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        );
        await _pulseCircleManager!.update(_pulseCircle!);
      }

      debugPrint(
        'Updated image position to: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error updating image annotation position: $e');
    }
  }

  // Add this method to update the pulse effect
  void _updatePulseEffect() {
    if (_pulseCircle == null || _pulseCircleManager == null || mapboxMapController == null) return;
    
    try {
      // Calculate pulse size and opacity based on animation value
      // As animation progresses, make circle larger and more transparent
      final animationValue = _pulseAnimationController.value;
      final baseRadius = 15.0; // Base radius of image
      final maxRadius = 45.0;  
      
      // Increase radius and decrease opacity as animation progresses
      final currentRadius = baseRadius + (maxRadius - baseRadius) * animationValue;
      final currentOpacity = 1.0 - animationValue; // Fade out as it expands
      
      // Update circle properties
      _pulseCircle!.circleRadius = currentRadius;
      _pulseCircle!.circleOpacity = currentOpacity;
      _pulseCircle!.circleColor = 0xFF007AFF;
      
      _pulseCircleManager!.update(_pulseCircle!);
      
      // Update custom pulse effect as well
      CustomLocationService.updateCustomPulseEffect(_pulseAnimationController);
    } catch (e) {
      debugPrint('Error updating pulse effect: $e');
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
        final hasPermission = await _requestLocationPermission();
        if (!hasPermission) return;
      }

      // Check if location services are enabled
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Permission granted - get location and animate
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Update location component settings to DISABLE the default blue/white puck
      await mapboxMapController!.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: false, // Important: disable default location puck
          pulsingEnabled: false, // Disable pulsing effect
        ),
      );

      // Animate to user's location with same animation as location button
      mapboxMapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 15.0,
          bearing: 0.0,
          pitch: 60.0,
        ),
        mp.MapAnimationOptions(duration: 2000),
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

    // Permission granted but don't animate to location yet
    if (permission == gl.LocationPermission.whileInUse) {
      // First show background permission dialog 
      await _showBackgroundLocationDialog();
      // Now animate to location after user has responded to dialog
      _animateToUserLocation();
    } else if (permission == gl.LocationPermission.always) {
      // Already has background permission, animate directly
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

  Future<void> _showBackgroundLocationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Allow background location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'For better experience, please allow the location to be used all the time in the settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          // On Android, we need to take users to settings for background permission
                          await gl.Geolocator.openAppSettings();
                        },
                        child: const Text('Go to settings'),
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


  void flyToSafeZone(double latitude, double longitude, String locationName, {int? safeZoneId}) async {
    if (mapboxMapController != null) {
      debugPrint('Flying to safe zone: $locationName at $latitude, $longitude');
      
      // Store the safe zone ID and name for later use
      setState(() {
        _currentSafeZoneId = safeZoneId;
        _currentSafeZoneName = locationName;
      });
      
      // First check if this safe zone already has a bounding box
      bool hasBoundingBox = false;
      if (safeZoneId != null) {
        hasBoundingBox = await SupabaseService.hasBoundingBoxForSafeZone(safeZoneId);
      }
      
      // Fly to the location with appropriate pitch based on whether we have a bounding box
      mapboxMapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: 15.0,
          bearing: 0,
          pitch: hasBoundingBox ? 60.0 : 0.0, // Use 60 degree pitch if bounding box exists
        ),
        mp.MapAnimationOptions(duration: 1500),
      );

      // Only enter safe zone mode if there's no existing bounding box
      if (!hasBoundingBox) {
        debugPrint('No bounding box found for this safe zone, entering safe zone mode');
        
        // Wait for the camera to finish moving
        await Future.delayed(const Duration(milliseconds: 2000));
        
        // Enter safe zone mode
        setState(() {
          _isInSafeZoneMode = true;
        });
        
        // Disable map gestures when entering safe zone mode
        _handleMapToggle(true);
        
        // Zoom in closer for better bounding box editing
        mapboxMapController!.flyTo(
          mp.CameraOptions(
            center: mp.Point(coordinates: mp.Position(longitude, latitude)),
            zoom: 17.0,
          ),
          mp.MapAnimationOptions(duration: 1000),
        );

        // Add bounding box overlay
        await BoundingBoxWidget.addGreenDotToMap(mapboxMapController!, latitude, longitude);
      } else {
        debugPrint('Bounding box already exists for this safe zone, staying in normal mode with 60 degree pitch');
        
        // Just load and refresh the bounding boxes to ensure this one is visible
        await _loadAndDisplayBoundingBoxes();
      }
    }
  }

  void _handleMapToggle(bool isDisabled) {
    if (mapboxMapController != null) {
      // Configure map gestures based on the disabled state
      mapboxMapController!.gestures.updateSettings(
        mp.GesturesSettings(
          rotateEnabled: !isDisabled,
          scrollEnabled: !isDisabled,
          doubleTapToZoomInEnabled: !isDisabled,
          doubleTouchToZoomOutEnabled: !isDisabled,
          quickZoomEnabled: !isDisabled,
          pinchToZoomEnabled: !isDisabled,
        ),
      );
      
      debugPrint('Map gestures set to ${isDisabled ? 'disabled' : 'enabled'}');
    }
  }

  // Exit safe zone mode and return camera to normal view
  void _exitSafeZoneMode() async {
    debugPrint('Exiting safe zone mode');
    
    // Clear the bounding box when exiting without saving
    await BoundingBoxWidget.clearBoundingBox();
    
    // First exit safe zone mode immediately to hide toolbar and show regular UI
    setState(() {
      _isInSafeZoneMode = false;
    });
    
    // Re-enable map gestures
    _handleMapToggle(false);
    
    // Continue with camera animation in the background
    try {
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );
      
      // First animate to user location (keeping pitch at 0)
      mapboxMapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(position.longitude, position.latitude)),
          zoom: 18.0,
          pitch: 0.0,
          bearing: 0.0
        ),
        mp.MapAnimationOptions(duration: 1500),
      );
      
      // Wait for first animation to complete
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Then animate the pitch to 60 degrees
      mapboxMapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(position.longitude, position.latitude)),
          zoom: 18.0,
          pitch: 60.0,
        ),
        mp.MapAnimationOptions(duration: 1500),
      );
      
    } catch (e) {
      debugPrint('Error getting location when exiting safe zone: $e');
      // The safe zone mode is already exited, so we don't need to do anything here
    }
  }

  // Method to save the current bounding box to database
  void _saveBoundingBox() async {
    if (_currentSafeZoneId == null || _currentSafeZoneName == null) {
      debugPrint('Cannot save bounding box: No safe zone selected');
      return;
    }
    
    try {
      await BoundingBoxWidget.saveBoundingBoxToDatabase(
        _currentSafeZoneId!,
        _currentSafeZoneName!,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bounding box saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error saving bounding box: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving bounding box'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Save bounding box and exit safe zone mode without changing location
  void _saveAndExitSafeZoneInPlace() async {
    debugPrint('Saving and exiting safe zone mode while staying in place');
    
    // First save the bounding box
    if (_currentSafeZoneId == null || _currentSafeZoneName == null) {
      debugPrint('Cannot save bounding box: No safe zone selected');
      // Even if we can't save, still exit safe zone mode
    } else {
      try {
        await BoundingBoxWidget.saveBoundingBoxToDatabase(
          _currentSafeZoneId!,
          _currentSafeZoneName!,
        );
        
        // Clear only the dots but keep the polygon
        await BoundingBoxWidget.clearDotsOnly();
        
        // Reload bounding boxes from database to ensure they display correctly
        await _loadAndDisplayBoundingBoxes();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safe zone boundary saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        debugPrint('Error saving bounding box: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save safe zone boundary'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    
    // Exit safe zone mode immediately to hide toolbar and show regular UI
    setState(() {
      _isInSafeZoneMode = false;
    });
    
    // Re-enable map gestures
    _handleMapToggle(false);
    
    // Animate just the pitch without changing position
    mapboxMapController!.flyTo(
      mp.CameraOptions(
        pitch: 60.0, // Change to 60 degree pitch
      ),
      mp.MapAnimationOptions(duration: 1500), 
    );
  }

  // Method to enter navigation mode with coordinates
  void enterNavigationMode(
    double sourceLat,
    double sourceLng,
    double destLat,
    double destLng,
    {String? sourceName, String? destName}
  ) async {
    if (mapboxMapController == null) return;
    setState(() {
      _isInNavigationMode = true;
      _navigationSourceName = sourceName;
      _navigationDestName = destName;
    });
    _updateCompassPosition();
    PathService.setRouteCoordinates(
      sourceLat: sourceLat,
      sourceLng: sourceLng,
      destLat: destLat,
      destLng: destLng,
      sourceName: sourceName,
      destName: destName
    );
    await Future.delayed(const Duration(milliseconds: 100));
    await PathService.displayPath(mapboxMapController);
  }

  void _exitNavigationMode() {
    setState(() {
      _isInNavigationMode = false;
      _navigationSourceName = null;
      _navigationDestName = null;
    });
    _updateCompassPosition();
    _animateToUserLocation();
    PathService.clearPath(mapboxMapController);
  }

  void _updateCompassPosition() {
    mapboxMapController?.compass.updateSettings(
      mp.CompassSettings(
        position: mp.OrnamentPosition.TOP_RIGHT,
        marginRight: 16,
        marginTop: _isInNavigationMode ? 190 : 50,
        enabled: true,
      ),
    );
  }
}
