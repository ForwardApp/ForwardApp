import 'package:flutter/material.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const AppBottomNavigationBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              if (onTap != null) onTap!(0);
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/map');
              }
            },
            child: Icon(
              Icons.map,
              color: Colors.grey,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (onTap != null) onTap!(1);
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: Icon(
              Icons.home,
              color: Colors.grey,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (onTap != null) onTap!(2);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('lib/assets/andriii.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}