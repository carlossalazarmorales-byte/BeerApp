/// Supplies the bearer token [ApiClient] attaches to FastAPI requests.
///
/// Deliberately an interface, not a typedef closing over `supabase_flutter`
/// directly — [ApiClient] stays testable with a fake implementation, and no
/// non-`data/` code needs to depend on `supabase_flutter`.
abstract class AccessTokenProvider {
  /// Returns a usable access token, or `null` if there is no authenticated
  /// session (including when a needed refresh failed). Absence is a normal,
  /// expected outcome here, never an exception.
  Future<String?> getAccessToken();
}
