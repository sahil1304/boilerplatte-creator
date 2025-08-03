import 'package:flutter/material.dart';

class CodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const CodeInputField({
    super.key,
    required this.controller,
    this.label = 'File Content',
    this.hint = 'Enter your code here or use AI to generate it...',
    this.maxLines = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // full width
      color: const Color(0xFF1E1E1E), // dark background
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'FiraMono', // Ensure in pubspec.yaml
              fontSize: 13,
            ),
            maxLines: maxLines,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(12),
              hintText: 'Enter your code here or use AI to generate it...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: true,
              fillColor: Color(0xFF1E1E1E), // match container
            ),
            cursorColor: Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }
}
