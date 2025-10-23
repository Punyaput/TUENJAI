// lib/widgets/custom_fade_route.dart

import 'package:flutter/material.dart';

// We create a new class that extends PageRouteBuilder
class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadeRoute({required this.child})
    : super(
        // Set the duration to be fast
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 200),

        // pageBuilder just returns the screen we're navigating to
        pageBuilder: (context, animation, secondaryAnimation) => child,

        // transitionsBuilder is where the magic happens
        transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
          // 'animation' is a value that goes from 0.0 to 1.0 as the page animates
          return FadeTransition(
            opacity: animation, // Use the animation value to drive the fade
            child: pageChild,
          );
        },
      );
}
