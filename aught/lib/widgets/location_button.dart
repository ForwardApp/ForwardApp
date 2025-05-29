import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'dart:math' as math;

class LocationButton extends StatefulWidget {
  final mp.MapboxMap? mapboxMapController;

  const LocationButton({super.key, required this.mapboxMapController});

  @override
  State<LocationButton> createState() => _LocationButtonState();
}

class _LocationButtonState extends State<LocationButton> {
  bool _isFollowingLocation = false;
  bool _isAnimatingToLocation = false; // Add this flag
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    _startTrackingCameraPosition();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _startTrackingCameraPosition() {
    // Check camera position every second to see if we're still following the user
    _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkIfFollowingLocation();
    });
  }

  Future<void> _checkIfFollowingLocation() async {
    if (widget.mapboxMapController == null) return;

    // Don't check if we're currently animating to location
    if (_isAnimatingToLocation) return;

    try {
      // Get current user position
      final userPosition = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Get current camera position
      final cameraState = await widget.mapboxMapController!.getCameraState();
      final cameraCenter = cameraState.center;

      // Calculate distance between camera center and user location
      final distance = _calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        cameraCenter.coordinates.lat.toDouble(),
        cameraCenter.coordinates.lng.toDouble(),
      );

      // If camera is within 50 meters of user location, consider it "following"
      final bool isNowFollowing = distance < 50; // 50 meters threshold

      if (isNowFollowing != _isFollowingLocation) {
        setState(() {
          _isFollowingLocation = isNowFollowing;
        });
      }
    } catch (e) {
      debugPrint('Error checking camera position: $e');
    }
  }

  // Calculate distance between two points in meters
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'locationButton',
        onPressed: _centerOnUserLocation,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 4,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Icon(
          (_isFollowingLocation || _isAnimatingToLocation)
              ? Icons.my_location
              : Icons.gps_not_fixed,
          size: 24,
        ),
      ),
    );
  }

  void _centerOnUserLocation() async {
    if (widget.mapboxMapController == null) return;

    // Set animation flag and update icon immediately
    setState(() {
      _isAnimatingToLocation = true;
      _isFollowingLocation = true;
    });

    try {
      // Check permission before trying to get location
      final permission = await gl.Geolocator.checkPermission();

      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        // Permission not granted, request it
        final newPermission = await gl.Geolocator.requestPermission();

        if (newPermission == gl.LocationPermission.denied ||
            newPermission == gl.LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          // Reset both flags if permission denied
          setState(() {
            _isAnimatingToLocation = false;
            _isFollowingLocation = false;
          });
          return;
        }
      }

      // Check if location services are enabled
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        // Reset both flags if location services disabled
        setState(() {
          _isAnimatingToLocation = false;
          _isFollowingLocation = false;
        });
        return;
      }

      // Get the user's current location
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );

      // Update location component settings
      await widget.mapboxMapController!.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: false, // Keep location component disabled
          pulsingEnabled: false, // Disable default pulsing effect
          puckBearingEnabled: false,
        ),
      );

      // Set camera to user's location with animation
      widget.mapboxMapController!.flyTo(
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

      // After 3 seconds (animation duration), clear the animation flag
      Timer(const Duration(seconds: 3), () {
        setState(() {
          _isAnimatingToLocation = false;
        });
        // After animation completes, the regular tracking will determine the icon state
      });
    } catch (e) {
      debugPrint('Error centering on user location: $e');
      // Reset both flags if there was an error
      setState(() {
        _isAnimatingToLocation = false;
        _isFollowingLocation = false;
      });
    }
  }
}
