import 'package:flutter/material.dart';
import '../widgets/safe_zone_list.dart';
import 'location_input_fragment.dart';
import '../services/supabase_service.dart';

class SafeHomeScreen extends StatefulWidget {
  const SafeHomeScreen({super.key});

  @override
  State<SafeHomeScreen> createState() => _SafeHomeScreenState();
}

class _SafeHomeScreenState extends State<SafeHomeScreen> {
  final TextEditingController _location1Controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _location1Address = '';
  double? _location1Lat;
  double? _location1Lng;
  List<Map<String, dynamic>> _allSafeZones = [];
  List<Map<String, dynamic>> _filteredSafeZones = [];

  @override
  void initState() {
    super.initState();
    _loadSafeZones();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _location1Controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeZones() async {
    try {
      if (!SupabaseService.isInitialized) {
        await SupabaseService.initialize();
      }
      
      final response = await SupabaseService.client
          .from('safe_zone')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _allSafeZones = List<Map<String, dynamic>>.from(response);
        _filteredSafeZones = _allSafeZones;
      });
    } catch (e) {
      debugPrint('Error loading safe zones: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredSafeZones = _allSafeZones;
      } else {
        _filteredSafeZones = _allSafeZones.where((zone) {
          final locationName = (zone['location_name'] ?? '').toString().toLowerCase();
          final locationAddress = (zone['location_address'] ?? '').toString().toLowerCase();
          return locationName.contains(query) || locationAddress.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _saveToSafeZone() async {
    try {
      await SupabaseService.saveSafeZone(
        locationName: _location1Controller.text,
        locationAddress: _location1Address,
        locationLat: _location1Lat,
        locationLng: _location1Lng,
      );
      
      setState(() {
        _location1Controller.clear();
        _location1Address = '';
        _location1Lat = null;
        _location1Lng = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safe zone saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error saving safe zone: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving safe zone'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar with location input (fixed at top)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Location 1 input field with left padding
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 20,
                          top: 15,
                          bottom: 20,
                        ),
                        child: Row(
                          children: [
                            // Back button inside Row
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.black54,
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search Safe Zones',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black, width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black, width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                          child: Icon(
                                            Icons.clear,
                                            color: Colors.black54,
                                            size: 20,
                                          ),
                                        )
                                      : null,
                                ),
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (_location1Controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveToSafeZone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.black, width: 1),
                                ),
                              ),
                              child: Text(
                                'Add ${_location1Controller.text}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (_location1Controller.text.isNotEmpty)
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),

              // Content below top bar
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: _searchController.text.isNotEmpty
                      ? _buildSearchResults()
                      : SafeZoneList(),
                ),
              ),
            ],
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationInputScreen(
                title: 'Select Location',
              ),
            ),
          );
          if (result != null) {
            if (result is Map<String, dynamic>) {
              setState(() {
                _location1Controller.text = result['name'] ?? '';
                _location1Address = result['address'] ?? '';
                _location1Lat = result['lat'];
                _location1Lng = result['lng'];
              });
            } else if (result is String) {
              setState(() {
                _location1Controller.text = result;
              });
            }
          }
        },
        backgroundColor: Colors.black,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredSafeZones.isEmpty) {
      return const Center(
        child: Text(
          'No safe zones found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: _filteredSafeZones.map((safeZone) => 
          _buildSafeZoneItem(context, safeZone)).toList(),
      ),
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
              'id': safeZone['id'],
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