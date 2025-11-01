// lib/widgets/custom_bottom_navigation.dart

import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use ClipRRect to enable rounded corners for the BackdropFilter
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24.0), // Rounded top corners
      ),
      child: BackdropFilter(
        // Apply the blur effect
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 90, // Adjusted height for larger, icon-only buttons
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            // Translucent white color for the "glass" effect
            color: Colors.white.withValues(alpha: 1), // Lowered opacity
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
            // Softer shadow
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            // Optional: Add a subtle border
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center, // Center items
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.group_outlined, // Use outlined icon
                selectedIcon: Icons.group, // Use solid icon when selected
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.home_outlined, // Use outlined icon
                selectedIcon: Icons.home,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.settings_outlined, // Use outlined icon
                selectedIcon: Icons.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the animated, icon-only navigation button.
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = currentIndex == index;

    // Define animated properties
    final double buttonSize = isSelected ? 70 : 54; // Bigger when selected
    final double iconSize = isSelected ? 30 : 26;
    final Color iconColor = isSelected
        ? Colors.white
        : const Color(0xFF6B7280); // Darker grey
    final Color buttonColor = isSelected
        ? const Color(0xFF2E88F3) // Blue when selected
        : Colors.grey.withValues(alpha: 0.1); // Translucent white when not
    final List<BoxShadow> shadow = isSelected
        ? [
            // "Pop out" shadow
            BoxShadow(
              color: const Color(0xFF2E88F3).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        : []; // No shadow when not selected

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque, // Makes the whole tap area work
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), // Animation speed
        curve: Curves.easeInOut, // Sleek animation curve
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(16), // Rounded square
          boxShadow: shadow,
        ),
        child: Icon(
          isSelected ? selectedIcon : icon, // Switch icon
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
