import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class LocationList extends StatefulWidget {
  const LocationList({super.key});

  @override
  State<LocationList> createState() => _LocationListState();
}

class _LocationListState extends State<LocationList> {
  Future<List<Map<String, dynamic>>>? _locationsFuture;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _fetchLocations();
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
        
        if (locations.isEmpty) {
          return const Center(
            child: Text('No locations saved yet', 
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }
        
        return SingleChildScrollView(
          child: Column(
            children: locations.map((location) => 
              _buildLocationItem(context, location)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLocationItem(BuildContext context, Map<String, dynamic> location) {
    return Column(
      children: [
        Padding(
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
