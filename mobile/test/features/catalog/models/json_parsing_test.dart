import 'package:beerapp/features/catalog/domain/models/json_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null returns null', () {
    expect(parseNullableDouble(null), isNull);
  });

  test('a bare JSON number parses directly', () {
    expect(parseNullableDouble(4.2), 4.2);
    expect(parseNullableDouble(4), 4.0);
  });

  test('a numeric string parses -- the actual wire format for this backend\'s '
      'Decimal fields (Pydantic v2 serializes Decimal as a JSON string, e.g. '
      '"4.20", not a bare number)', () {
    expect(parseNullableDouble('4.20'), 4.2);
    expect(parseNullableDouble('-6.260310'), -6.26031);
  });

  test('an unsupported type throws a clear FormatException', () {
    expect(() => parseNullableDouble(true), throwsFormatException);
    expect(
      () => parseNullableDouble(<String, dynamic>{}),
      throwsFormatException,
    );
  });
}
