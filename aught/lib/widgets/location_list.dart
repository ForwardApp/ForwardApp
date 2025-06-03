import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mapbox_search_service.dart';
import '../screens/map_screen.dart';

class LocationList extends StatefulWidget {
  final Function(Map<String, dynamic>)? onLocationSelected;
  
  const LocationList({
    super.key, 
    this.onLocationSelected,
  });

  @override
  State<LocationList> createState() => _LocationListState();
}

class _LocationListState extends State<LocationList> {
  Future<List<Map<String, dynamic>>>? _locationsFuture;
  Position? _currentUserPosition;
  String _currentLocationAddress = "Getting current location...";
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _fetchLocations();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied ||
            requestPermission == LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          setState(() {
            _isLoadingLocation = false;
            _currentLocationAddress = "Location access denied";
          });
          return;
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        setState(() {
          _isLoadingLocation = false;
          _currentLocationAddress = "Location services disabled";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentUserPosition = position;
        _currentLocationAddress = "Getting address...";
      });
      
      // Get readable address from coordinates
      final address = await MapboxSearchService.reverseGeocode(position.latitude, position.longitude);
      
      setState(() {
        _isLoadingLocation = false;
        if (address != null && address.isNotEmpty) {
          _currentLocationAddress = address;
        } else {
          // Fallback to coordinates if address lookup fails
          _currentLocationAddress = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        }
      });
    } catch (e) {
      debugPrint('Error getting current location: $e');
      setState(() {
        _isLoadingLocation = false;
        _currentLocationAddress = "Could not determine location";
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLocations() async {
    try {
      debugPrint('Fetching locations from Supabase...');
      
      // Make sure Supabase is initialized before using it
      if (!SupabaseService.isInitialized) {
        debugPrint('Supabase not initialized, trying to initialize...');
        await SupabaseService.initialize();
      }
      
      final response = await SupabaseService.client
          .from('location_list')
          .select()
          .order('created_at', ascending: false);
      
      final locations = List<Map<String, dynamic>>.from(response);
      debugPrint('Found ${locations.length} locations in database');
      
      return locations;
    } catch (e) {
      debugPrint('Error fetching locations: $e');
      // Return empty list on error
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _locationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final locations = snapshot.data ?? [];
        
        return SingleChildScrollView(
          child: Column(
            children: [
              // Your Location at the top
              _buildCurrentLocationItem(context),
              
              // Empty state message if no saved locations
              if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No locations saved yet', 
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ),
                
              // Saved locations
              ...locations.map((location) => _buildLocationItem(context, location)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentLocationItem(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (_currentUserPosition != null) {
              debugPrint('Current location tapped');
              
              // Call the callback with location data instead of popping
              if (widget.onLocationSelected != null) {
                widget.onLocationSelected!({
                  'name': _currentLocationAddress,
                  'address': _currentLocationAddress,
                  'lat': _currentUserPosition!.latitude,
                  'lng': _currentUserPosition!.longitude,
                });
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blue, size: 24),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingLocation ? "Getting location..." : _currentLocationAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildLocationItem(BuildContext context, Map<String, dynamic> location) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            debugPrint('Location item tapped: ${location['first_location_name']} to ${location['second_location_name']}');
            
            // Get coordinate data
            final firstLat = location['first_location_lat'];
            final firstLng = location['first_location_lng'];
            final secondLat = location['second_location_lat'];
            final secondLng = location['second_location_lng'];
            
            // Debug prints to verify coordinates
            debugPrint('Source coordinates: ($firstLat, $firstLng)');
            debugPrint('Destination coordinates: ($secondLat, $secondLng)');
            
            // Check if we have valid coordinates
            if (firstLat != null && firstLng != null && secondLat != null && secondLng != null) {
              // Directly navigate to map and show route instead of just returning data
              MapScreen.navigateToRoute(
                firstLat,
                firstLng,
                secondLat,
                secondLng,
                sourceName: location['first_location_name'] ?? 'Start',
                destName: location['second_location_name'] ?? 'End'
              );
              
              // Close this screen after triggering navigation
              Navigator.pop(context);
            } else {
              debugPrint('Invalid coordinates for navigation in location: ${location['id']}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Red location icon - left aligned
                const Icon(Icons.location_on, color: Colors.red, size: 24),

                const SizedBox(width: 12),

                // Location names column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location['first_location_name'] ?? 'Unknown location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location['second_location_name'] ?? 'Unknown location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Read more button - right aligned
                IconButton(
                  onPressed: () {
                    _showMoreInfoModal(context, location);
                  },
                  icon: const Icon(
                    Icons.menu_book,
                    color: Colors.black54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Horizontal line - 90% of screen width
        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }

  void _showMoreInfoModal(BuildContext context, Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location['first_location_name'] ?? 'Unknown location',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          if (location['first_location_address'] != null && 
                              location['first_location_address'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              location['first_location_address'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            location['second_location_name'] ?? 'Unknown location',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          if (location['second_location_address'] != null && 
                              location['second_location_address'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              location['second_location_address'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          _getTransportIcon(location['transport_mode']),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          location['start_time'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location['end_time'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
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

  Widget _getTransportIcon(String? transportMode) {
    IconData iconData;
    switch (transportMode?.toLowerCase()) {
      case 'car':
        iconData = Icons.directions_car;
        break;
      case 'bike':
        iconData = Icons.directions_bike;
        break;
      case 'walk':
      default:
        iconData = Icons.directions_walk;
        break;
    }
    
    return Icon(
      iconData,
      size: 20,
      color: Colors.black,
    );
  }
}
