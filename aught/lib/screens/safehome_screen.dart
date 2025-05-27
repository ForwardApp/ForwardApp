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
  String _location1Address = '';
  double? _location1Lat;
  double? _location1Lng;

  @override
  void dispose() {
    _location1Controller.dispose();
    super.dispose();
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
                          left: 50,
                          right: 20,
                          top: 15,
                          bottom: 20,
                        ),
                        child: GestureDetector(
                          onTap: () async {
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
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _location1Controller,
                              decoration: const InputDecoration(
                                hintText: 'Choose destination',
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
                              ),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
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
                              child: const Text(
                                'Save Home',
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
                  child: const SafeZoneList(),
                ),
              ),
            ],
          ),

          // Back button positioned in top left
          Positioned(
            left: 8,
            top: 50,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black54,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}