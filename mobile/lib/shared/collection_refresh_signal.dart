import 'package:flutter/foundation.dart';

/// Mutation-driven freshness signal for the Collection screen. Any
/// successful mutation that can change Collection's contents (a beer-log
/// create/update/delete, a favorite/wishlist change) calls [notifyChanged]
/// after it succeeds; `CollectionController` listens and refreshes.
///
/// Deliberately not navigation-driven (no `RouteObserver`/`RouteAware`
/// hook): `BeerDetailScreen` is a top-level route on the root navigator
/// while `CollectionScreen` lives inside its own `StatefulShellBranch`
/// navigator, so a pop-driven refresh would only fire on an actual
/// push/pop -- missing the case where the user returns to a *different*
/// tab first and only later switches to Collection via the bottom nav. This
/// signal works regardless of navigation history or which tab a mutation
/// happened from, because `StatefulShellRoute.indexedStack` keeps every
/// branch's widget subtree (and therefore `CollectionController`, which
/// listens here) mounted and responsive even while a different tab is
/// visible -- see docs/DECISIONS.md.
class CollectionRefreshSignal extends ChangeNotifier {
  void notifyChanged() => notifyListeners();
}
