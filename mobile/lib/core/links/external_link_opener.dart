import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in the user's own browser (never an in-app WebView).
///
/// An interface so screens can be tested without launching anything.
abstract interface class ExternalLinkOpener {
  /// True if a handler was launched, false if nothing could open [uri] or the
  /// launch failed. Never throws, and never logs the URL.
  Future<bool> open(Uri uri);
}

/// The production opener, backed by `url_launcher` (already a transitive
/// dependency of `supabase_flutter`, made direct because the app now calls it).
class UrlLauncherLinkOpener implements ExternalLinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A platform failure is reported as "could not open" -- the caller shows
      // one localized message; the exception text is never surfaced.
      return false;
    }
  }
}
