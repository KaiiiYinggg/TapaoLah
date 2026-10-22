import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StylishBottomBar(
      option: AnimatedBarOptions(
        iconSize: 28,
        barAnimation: BarAnimation.fade,
        iconStyle: IconStyle.animated,
        opacity: 0.3,
      ),
      items: [
        BottomBarItem(
          icon: const Icon(Icons.home),
          title: const Text('Home'),
          selectedColor: Colors.teal,
        ),
        BottomBarItem(
          icon: const Icon(Icons.monetization_on),
          title: const Text('Billing'),
          selectedColor: Colors.teal,
        ),
        BottomBarItem(
          icon: const Icon(Icons.person),
          title: const Text('Information'),
          selectedColor: Colors.teal,
        ),
      ],
      hasNotch: false,
      currentIndex: currentIndex,
      backgroundColor: Colors.white,
      onTap: onTap,
    );
  }
}
