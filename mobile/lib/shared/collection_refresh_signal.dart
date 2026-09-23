import 'package:flutter/foundation.dart';

/// Mutation-driven freshness signal for any screen whose contents depend on
/// the user's own beer logs/collection state. Any successful mutation that
/// can change that state (a beer-log create/update/delete, a favorite/
/// wishlist change) calls [notifyChanged] after it succeeds;
/// `CollectionController` and `DiscoverController` both listen and refresh
/// -- Discover's untried-only feed must stop showing a beer the instant it
/// gets logged (from Add Beer today), exactly the same requirement
/// Collection already had. The name predates Discover becoming a second
/// consumer (QA Round 1 Block 1 follow-up); kept rather than renamed to
/// limit the diff, since every existing call site's behavior is unchanged.
///
/// Deliberately not navigation-driven (no `RouteObserver`/`RouteAware`
/// hook): `BeerDetailScreen` is a top-level route on the root navigator
/// while `CollectionScreen`/`DiscoverScreen` each live inside their own
/// `StatefulShellBranch` navigator, so a pop-driven refresh would only fire
/// on an actual push/pop -- missing the case where the user returns to a
/// *different* tab first and only later switches to the affected tab via
/// the bottom nav. This signal works regardless of navigation history or
/// which tab a mutation happened from, because `StatefulShellRoute.
/// indexedStack` keeps every branch's widget subtree (and therefore each
/// listening controller) mounted and responsive even while a different tab
/// is visible -- see docs/DECISIONS.md.
class CollectionRefreshSignal extends ChangeNotifier {
  void notifyChanged() => notifyListeners();
}
