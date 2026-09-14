import 'package:flutter/widgets.dart';

/// Corner-radius scale (logical pixels). A fresh, internally-consistent
/// scale rather than a literal port of Stitch's numbers — the Stitch
/// `DESIGN.md` prose (`lg=1rem`/`xl=1.5rem`) and the Tailwind config
/// embedded in every Stitch screen (`lg=0.5rem`/`xl=0.75rem`) disagree with
/// each other, so this scale is treated as directional inspiration only.
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;

  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}
