/// Flashes the browser tab's title so an incoming call is noticeable even
/// when the admin dashboard isn't the focused tab - the call screen's own
/// ringtone (see call_screen.dart) covers "admin has sound on and is
/// nearby", this covers "admin is looking at a different tab".
///
/// Same conditional-export pattern as report_printer.dart/
/// csv_downloader.dart, for the same reason: this file is reachable from
/// the shared `lib/main.dart` import graph that Android/iOS builds compile
/// too, so it must not pull in `dart:html` there.
library;

export 'tab_title_alert_stub.dart' if (dart.library.html) 'tab_title_alert_web.dart';
