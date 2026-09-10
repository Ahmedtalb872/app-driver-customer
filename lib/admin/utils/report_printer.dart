/// Opens [bodyHtml] in a hidden same-origin iframe and asks the browser to
/// print it, which is how the admin dashboard exports a report as PDF
/// ("Save as PDF" / "طباعة إلى PDF" in the browser's own print dialog).
///
/// Deliberately not the `pdf`/`printing` packages: those rasterise text
/// with a bundled TTF, and this dashboard is entirely Arabic - correct
/// Arabic shaping and RTL there would mean committing an Arabic font
/// binary and still fighting bidi edge cases, while the browser already
/// renders the exact same text perfectly on screen. Same conditional
/// export pattern as csv_downloader.dart, for the same reason: this file
/// is reachable from the shared `lib/main.dart` import graph that
/// Android/iOS builds compile too, so it must not pull in `dart:html`
/// there.
library;

export 'report_printer_stub.dart'
    if (dart.library.html) 'report_printer_web.dart';
