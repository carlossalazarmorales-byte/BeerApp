import 'package:flutter/material.dart';

/// A reusable styled text field. Visual styling (fill color, radius, focus
/// ring, no bottom line) comes from [ThemeData.inputDecorationTheme] set in
/// `AppTheme`, so this widget only needs to wire up content.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.leadingIcon,
    this.obscureText = false,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;
  final IconData? leadingIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: leadingIcon == null ? null : Icon(leadingIcon),
      ),
    );
  }
}
