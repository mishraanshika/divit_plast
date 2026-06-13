import 'package:flutter/material.dart';
import 'package:manufacturing_app/widget/text_field.dart';

class AppNumberField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;

  const AppNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: label,
      controller: controller,
      required: required,
      keyboardType: TextInputType.number,
      errorMessage: '$label is required',
    );
  }
}
