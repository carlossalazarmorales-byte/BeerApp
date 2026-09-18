/// Boundary for account-lifecycle operations that require server-side
/// privilege (unlike `ProfileRepository`, which the client writes directly
/// via Supabase RLS). Backed by FastAPI's `DELETE /account`, the first
/// endpoint touching account identity rather than just profile data — see
/// docs/DECISIONS.md.
abstract class AccountRepository {
  /// Calls `DELETE /account` for the caller's own (JWT-derived) account.
  /// Does NOT clear the local Supabase session itself — callers must do
  /// that explicitly afterward (see the Settings delete-account flow),
  /// since this repository has no knowledge of Supabase Auth session
  /// state.
  Future<void> deleteAccount();
}
