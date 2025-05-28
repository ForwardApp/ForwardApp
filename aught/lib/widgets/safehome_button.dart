import 'package:flutter/material.dart';
import '../screens/safehome_screen.dart';
import '../screens/map_screen.dart';

class SafeHomeButton extends StatelessWidget {
  const SafeHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'safeHomeButton',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SafeHomeScreen()),
          );
          
          if (result is Map<String, dynamic> &&
              result.containsKey('location_lat') &&
              result.containsKey('location_lng')) {
            
            final mapScreen = context.findAncestorWidgetOfExactType<MapScreen>();
            if (mapScreen != null) {
              MapScreen.flyToLocation(
                result['location_lat'],
                result['location_lng'],
                result['location_name'] ?? '',
                safeZoneId: result['id'],
              );
            }
          }
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 4,
        child: const Icon(Icons.add_home, size: 24),
      ),
    );
  }
}