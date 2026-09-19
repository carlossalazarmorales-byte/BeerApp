import 'package:flutter/material.dart';

/// Sentinel picker values. Ids from the catalog are UUIDs, so these can
/// never collide with a real option.
const String notListedValue = '__not_listed__';
const String noneValue = '__none__';

/// A dropdown over canonical catalog rows (id -> name) with a final "Not
/// listed" option. Choosing "Not listed" is how a user proposes something the
/// catalog lacks -- the screen then reveals a free-text field. It never
/// creates a catalog row: the proposal travels as a `proposed_*` string on
/// the contribution.
///
/// When [noneLabel] is given, a leading "none" option is offered too (for
/// genuinely optional pickers such as the beer style).
class CatalogPickerField extends StatelessWidget {
  const CatalogPickerField({
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.notListedLabel,
    this.noneLabel,
    this.validator,
    super.key,
  });

  final String hint;

  /// Catalog id -> display name, in display order.
  final Map<String, String> options;

  /// A catalog id, [notListedValue], [noneValue], or null (nothing chosen).
  final String? value;
  final ValueChanged<String?> onChanged;
  final String notListedLabel;
  final String? noneLabel;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(hint),
      decoration: const InputDecoration(),
      items: [
        if (noneLabel != null)
          DropdownMenuItem(value: noneValue, child: Text(noneLabel!)),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        DropdownMenuItem(value: notListedValue, child: Text(notListedLabel)),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}
