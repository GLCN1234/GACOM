// Real implementation — only compiled into web builds via the
// conditional import in supabase_service.dart. Never imported directly
// by anything that might also target iOS/Android.
import 'dart:html' as html;

void stripExpiredAuthLinkFromUrl() {
  try {
    final fragment = Uri.base.fragment;
    if (fragment.contains('error=access_denied') || fragment.contains('otp_expired')) {
      html.window.history.replaceState(null, '', Uri.base.path);
    }
  } catch (_) {
    // History API unavailable for some reason — nothing to strip, the
    // global friendly error screen still covers this as a fallback.
  }
}
