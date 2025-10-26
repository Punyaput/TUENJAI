// lib/screens/legal_display_screen.dart

import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class LegalDisplayScreen extends StatelessWidget {
  final String title;
  final String markdownContent;

  const LegalDisplayScreen({
    super.key,
    required this.title,
    required this.markdownContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title), // Display the passed title
      ),
      body: SafeArea(
        // Use MarkdownWidget column/list for better scrolling & styling
        child: Padding(
          // Add padding around the scrollable area
          padding: const EdgeInsets.all(16.0),
          child: MarkdownWidget(
            // USE NEW WIDGET
            data: markdownContent, // Pass the legal text string
            // Optional: Customize styles using config
            config: MarkdownConfig(
              configs: [
                // Configure paragraph style
                PConfig(
                  textStyle: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                // Configure H2 style
                H2Config(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                  ),
                ),
                // Add other configs as needed
              ],
            ),
          ),
        ),
      ),
    );
  }
}
