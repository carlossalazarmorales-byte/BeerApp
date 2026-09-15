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
    this.suffixIcon,
    this.obscureText = false,
    this.onChanged,
    this.validator,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? hintText;
  final IconData? leadingIcon;

  /// A trailing action, e.g. a clear button on a search field.
  final Widget? suffixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  /// A server-side error (e.g. "username taken") to show alongside/instead
  /// of [validator]'s client-side result.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        prefixIcon: leadingIcon == null ? null : Icon(leadingIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
