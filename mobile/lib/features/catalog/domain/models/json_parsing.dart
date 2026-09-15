/// Parses a nullable numeric JSON field that may legally arrive as either a
/// bare JSON number or a numeric string.
///
/// Verified against this project's actual backend: Pydantic v2 serializes
/// `Decimal` fields (`abv`, `latitude`, `longitude`,
/// `typical_abv_min`/`typical_abv_max`) to JSON as **strings** (e.g.
/// `"4.20"`), not bare numbers -- it does this to preserve precision,
/// across `model_dump_json()`, `model_dump(mode="json")`, and FastAPI's
/// `jsonable_encoder`, so there is no response path in this backend that
/// produces a bare number for these fields today. `int` fields (`ibu`) and
/// `bool` fields (`verified`) are unaffected and continue to arrive as
/// plain JSON numbers/booleans. This parser tolerates both representations
/// rather than hard-coding today's string form, so a future backend change
/// (e.g. a custom encoder that emits a bare number) wouldn't silently break
/// parsing again.
double? parseNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException(
    'Expected a number or numeric string, got $value (${value.runtimeType})',
  );
}
