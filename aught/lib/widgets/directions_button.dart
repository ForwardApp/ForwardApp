import 'package:flutter/material.dart';
import '../screens/directions_screen.dart';

class DirectionsButton extends StatelessWidget {
  const DirectionsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'directionsButton',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DirectionsScreen()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 4,
        child: const Icon(Icons.directions, size: 24),
      ),
    );
  }
}
