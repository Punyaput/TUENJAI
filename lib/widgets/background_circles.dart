import 'package:flutter/material.dart';

class TopBackgroundCircles extends StatelessWidget {
  const TopBackgroundCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 553,
      height: 267,
      child: Stack(
        children: [
          // First circle
          Positioned(
            top: 67,
            left: 0,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8ACE95).withOpacity(0.5),
              ),
            ),
          ),
          
          // Second circle
          Positioned(
            top: 0,
            left: 90,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8ACE95).withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomBackgroundCircles extends StatelessWidget {
  const BottomBackgroundCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 618,
      height: 354,
      child: Stack(
        children: [
          // Large blue circle
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 339,
              height: 339,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA3CDFF).withOpacity(0.7),
              ),
            ),
          ),
          
          // Medium blue circle 1
          Positioned(
            top: 108,
            left: 203,
            child: Container(
              width: 246,
              height: 246,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF78B6FF).withOpacity(0.9),
              ),
            ),
          ),
          
          // Medium blue circle 2
          Positioned(
            top: 69,
            left: 372,
            child: Container(
              width: 246,
              height: 246,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF78B6FF).withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}