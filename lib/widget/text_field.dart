import 'package:flutter/material.dart';

class AppFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final bool required;
  final String? errorMessage;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.errorMessage,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (value) {
            if (!required) return null;

            if (value == null || value.trim().isEmpty) {
              return errorMessage ?? 'This field is required';
            }

            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 11,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
