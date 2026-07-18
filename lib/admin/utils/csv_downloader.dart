/// Triggers a browser file download of [content] as [filename] on web, and
/// is a documented no-op on every other platform (the admin dashboard only
/// ever runs on web, but this file is still reachable from the shared
/// `lib/main.dart` import graph that Android/iOS builds compile too, so it
/// must not pull in `dart:html` there - see the conditional export below,
/// Flutter's standard pattern for this exact situation).
library;

export 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart';
