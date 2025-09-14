import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isEnabled;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 337,
      height: 63,
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFF2E88F3) : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isEnabled ? const Color(0xFFF3F3F3) : const Color(0xFF9CA3AF),
                height: 1.41,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}