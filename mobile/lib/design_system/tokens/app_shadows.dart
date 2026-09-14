import 'package:flutter/widgets.dart';

/// Shadow tokens matching the diffused "ambient shadow" spec from
/// `/stitch/amber_froth/DESIGN.md` (`0px 12px 32px rgba(41,24,10,0.06)`).
/// Only these two are promoted to tokens — a lighter variant appears on one
/// Stitch screen's bottom nav but is treated as drift, not a real second
/// value.
abstract final class AppShadows {
  static const Color _tint = Color.fromRGBO(41, 24, 10, 0.06);

  /// General elevated surfaces (cards floating above the background).
  static const List<BoxShadow> ambient = [
    BoxShadow(color: _tint, offset: Offset(0, 12), blurRadius: 32),
  ];

  /// The bottom navigation bar, which floats above content rather than
  /// below it, so the shadow is cast upward.
  static const List<BoxShadow> navUpward = [
    BoxShadow(color: _tint, offset: Offset(0, -12), blurRadius: 32),
  ];
}
