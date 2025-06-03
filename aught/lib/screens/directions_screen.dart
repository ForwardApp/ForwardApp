import 'package:flutter/material.dart';
import '../widgets/location_list.dart';
import 'location_input_fragment.dart';
import '../services/supabase_service.dart';

class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({super.key});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  // Update these variables to store address info
  final TextEditingController _location1Controller = TextEditingController();
  final TextEditingController _location2Controller = TextEditingController();
  String _location1Address = '';
  String _location2Address = '';
  double? _location1Lat;
  double? _location1Lng;
  double? _location2Lat;
  double? _location2Lng;
  TimeOfDay _selectedTime = TimeOfDay.now();
  late TimeOfDay _selectedTime2;
  int _selectedTransportIndex = 0; // 0 = walk, 1 = car, 2 = bike

  @override
  void initState() {
    super.initState();
    // Set second time to 4 hours from current time
    final now = TimeOfDay.now();
    final futureHour = (now.hour + 4) % 24; // Handle overflow past 24 hours
    _selectedTime2 = TimeOfDay(hour: futureHour, minute: now.minute);
  }

  @override
  void dispose() {
    _location1Controller.dispose();
    _location2Controller.dispose();
    super.dispose();
  }

  String _formatTime24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Select start time',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dialHandColor: Colors.blue,
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.blue.withOpacity(0.2);
                }
                return Colors.grey.shade400;
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue, // OK and Cancel buttons blue
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectTime2(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime2,
      helpText: 'Select end time',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dialHandColor: Colors.blue,
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.blue.withOpacity(0.2);
                }
                return Colors.grey.shade400;
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue, // OK and Cancel buttons blue
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null && picked != _selectedTime2) {
      setState(() {
        _selectedTime2 = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar with all controls (fixed at top)
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
                      // Input fields with left padding
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 50,
                          right: 20,
                          top: 15,
                        ),
                        child: Column(
                          children: [
                            // Location 1 input field
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LocationInputScreen(
                                      title: 'Choose Location',
                                      initialValue: _location1Controller.text,
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    if (result is Map<String, dynamic>) {
                                      _location1Controller.text = result['name'] ?? '';
                                      _location1Address = result['address'] ?? '';
                                      _location1Lat = result['lat'];
                                      _location1Lng = result['lng'];
                                    } else {
                                      _location1Controller.text = result;
                                    }
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _location1Controller,
                                  decoration: InputDecoration(
                                    hintText: 'Location 1',
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2.0,
                                      ),
                                    ),
                                    focusColor: Colors.white,
                                    hoverColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Location 2 input field
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LocationInputScreen(
                                      title: 'Choose Location',
                                      initialValue: _location2Controller.text,
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    if (result is Map<String, dynamic>) {
                                      _location2Controller.text = result['name'] ?? '';
                                      _location2Address = result['address'] ?? '';
                                      _location2Lat = result['lat'];
                                      _location2Lng = result['lng'];
                                    } else {
                                      _location2Controller.text = result;
                                    }
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _location2Controller,
                                  decoration: InputDecoration(
                                    hintText: 'Location 2',
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2.0,
                                      ),
                                    ),
                                    focusColor: Colors.white,
                                    hoverColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Time pickers row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // First time picker - left aligned
                                GestureDetector(
                                  onTap: () => _selectTime(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: Text(
                                      _formatTime24Hour(_selectedTime),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),

                                // Second time picker - right aligned
                                GestureDetector(
                                  onTap: () => _selectTime2(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: Text(
                                      _formatTime24Hour(_selectedTime2),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Transportation icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Walk icon
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTransportIndex = 0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedTransportIndex == 0
                                    ? Colors.grey[300]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_walk,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(width: 40),

                          // Car icon
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTransportIndex = 1;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedTransportIndex == 1
                                    ? Colors.grey[300]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(width: 40),

                          // Bicycle icon
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTransportIndex = 2;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedTransportIndex == 2
                                    ? Colors.grey[300]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_bike,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (_location1Controller.text.isNotEmpty &&
                          _location2Controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_location1Lat != null && _location1Lng != null && 
                                    _location2Lat != null && _location2Lng != null) {
                                  
                                  // First save to database
                                  try {
                                    await SupabaseService.saveRouteLocations(
                                      location1Name: _location1Controller.text,
                                      location2Name: _location2Controller.text,
                                      location1Address: _location1Address,
                                      location2Address: _location2Address,
                                      location1Lat: _location1Lat,
                                      location1Lng: _location1Lng,
                                      location2Lat: _location2Lat,
                                      location2Lng: _location2Lng,
                                      startTime: _formatTime24Hour(_selectedTime),
                                      endTime: _formatTime24Hour(_selectedTime2),
                                      transportMode: ['walk', 'car', 'bike'][_selectedTransportIndex],
                                    );
                                    
                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Route saved successfully!'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    
                                    // Navigate to map screen and pass route coordinates
                                    Navigator.pop(context, {
                                      'source_lat': _location1Lat,
                                      'source_lng': _location1Lng,
                                      'dest_lat': _location2Lat,
                                      'dest_lng': _location2Lng,
                                      'source_name': _location1Controller.text,
                                      'dest_name': _location2Controller.text,
                                    });
                                    
                                  } catch (e) {
                                    debugPrint('Error saving route: $e');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error saving route: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
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
                        ),

                      if (_location1Controller.text.isNotEmpty &&
                          _location2Controller.text.isNotEmpty)
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),

              // Content below top bar
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: LocationList(
                    onLocationSelected: (locationData) {
                      setState(() {
                        _location1Controller.text = locationData['name'];
                        _location1Address = locationData['address'];
                        _location1Lat = locationData['lat'];
                        _location1Lng = locationData['lng'];
                      });
                    },
                  ),
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
