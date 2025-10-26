// lib/widgets/otp_input_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String)
  onChanged; // This is called ONLY when a digit is entered
  // Removed index and allFocusNodes as they are not needed here anymore

  const OtpInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fieldSize = screenWidth * 0.11;

    return Container(
      width: fieldSize,
      height: fieldSize + 10,
      decoration: BoxDecoration(
        border: Border.all(
          color: focusNode.hasFocus || controller.text.isNotEmpty
              ? const Color(0xFF2E88F3)
              : const Color(0xFFD1D5DB),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        // Automatically select text when focused for easy overwrite
        onTap: () => controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
        style: TextStyle(
          fontSize: screenWidth * 0.055,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF374151),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          // ONLY call the parent onChanged when a digit is entered
          if (value.isNotEmpty) {
            onChanged(value);
          }
          // Backspace logic is handled by RawKeyboardListener in the parent screen
        },
      ),
    );
  }
}
