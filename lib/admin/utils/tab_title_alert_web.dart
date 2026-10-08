import 'dart:async';
import 'dart:html' as html;

Timer? _timer;
String? _originalTitle;

/// Alternates the tab title between [alertText] and whatever it was before
/// every second, until [stopTabTitleAlert] is called. Safe to call again
/// while already running (e.g. a second incoming call) - it just restarts
/// the blink without losing the real original title.
void startTabTitleAlert(String alertText) {
  _originalTitle ??= html.document.title;
  _timer?.cancel();
  var showingAlert = false;
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    showingAlert = !showingAlert;
    html.document.title = showingAlert ? alertText : (_originalTitle ?? '');
  });
}

void stopTabTitleAlert() {
  _timer?.cancel();
  _timer = null;
  final original = _originalTitle;
  if (original != null) {
    html.document.title = original;
  }
  _originalTitle = null;
}
