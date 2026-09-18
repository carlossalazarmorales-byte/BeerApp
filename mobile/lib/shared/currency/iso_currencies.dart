/// Small, hardcoded subset of ISO 4217 currency codes for BeerApp's Settings
/// currency picker -- a curated Settings-UX convenience, not an exhaustive
/// ISO 4217 list and not a validation source. The actual format constraint
/// is the database CHECK pattern (`^[A-Z]{3}$`) on both
/// `profiles.preferred_currency` and `user_beer_logs.currency` (see
/// supabase/migrations); this list only limits what the picker offers.
///
/// Lives in `shared/` rather than `features/auth` or `design_system`
/// because it's consumed by two unrelated features with no ownership
/// relationship -- Settings (`features/profile`) and the beer-log form
/// (`features/logging`) -- mirroring `CollectionRefreshSignal`'s placement.
const List<String> commonCurrencyCodes = [
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'CAD',
  'AUD',
  'JPY',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
];
