import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SafeZoneList extends StatefulWidget {
  const SafeZoneList({super.key});

  @override
  State<SafeZoneList> createState() => _SafeZoneListState();
}

class _SafeZoneListState extends State<SafeZoneList> {
  Future<List<Map<String, dynamic>>>? _safeZonesFuture;

  @override
  void initState() {
    super.initState();
    _safeZonesFuture = _fetchSafeZones();
  }

  Future<List<Map<String, dynamic>>> _fetchSafeZones() async {
    try {
      debugPrint('Fetching safe zones from Supabase...');
      
      if (!SupabaseService.isInitialized) {
        debugPrint('Supabase not initialized, trying to initialize...');
        await SupabaseService.initialize();
      }
      
      final response = await SupabaseService.client
          .from('safe_zone')
          .select()
          .order('created_at', ascending: false);
      
      final safeZones = List<Map<String, dynamic>>.from(response);
      debugPrint('Found ${safeZones.length} safe zones in database');
      
      return safeZones;
    } catch (e) {
      debugPrint('Error fetching safe zones: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _safeZonesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final safeZones = snapshot.data ?? [];
        
        if (safeZones.isEmpty) {
          return const Center(
            child: Text('No safe zones saved yet', 
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }
        
        return SingleChildScrollView(
          child: Column(
            children: safeZones.map((safeZone) => 
              _buildSafeZoneItem(context, safeZone)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSafeZoneItem(BuildContext context, Map<String, dynamic> safeZone) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            debugPrint('Safe zone tapped: ${safeZone['location_name']}');
            final lat = safeZone['location_lat'];
            final lng = safeZone['location_lng'];
            Navigator.pop(context, {
              'location_name': safeZone['location_name'] ?? 'Unknown location',
              'location_lat': lat,
              'location_lng': lng,
              'id': safeZone['id'], // Pass the ID back
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.home, color: Colors.green, size: 24),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeZone['location_name'] ?? 'Unknown location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      if (safeZone['location_address'] != null && 
                          safeZone['location_address'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          safeZone['location_address'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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
}