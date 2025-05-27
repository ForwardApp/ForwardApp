import 'package:flutter/material.dart';
import '../screens/safehome_screen.dart';

class SafeHomeButton extends StatelessWidget {
  const SafeHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'safeHomeButton',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SafeHomeScreen()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 4,
        child: const Icon(Icons.add_home, size: 24),
      ),
    );
  }
}