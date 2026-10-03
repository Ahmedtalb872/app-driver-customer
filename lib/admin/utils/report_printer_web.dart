import 'dart:async';
import 'dart:html' as html;

/// Prints [bodyHtml] as a standalone RTL A4 document.
///
/// The iframe is `srcdoc`-based (same origin, so its inline script runs)
/// and self-triggers `window.print()` on load; calling print() from inside
/// the iframe's own window is what makes the browser print just this
/// document instead of the whole dashboard behind it. The element is
/// removed a minute later - long enough that a slow user still has the
/// print dialog open, short enough that repeated exports don't pile up
/// dead iframes in the DOM.
void printReportHtml(String documentTitle, String bodyHtml) {
  final document =
      '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<title>$documentTitle</title>
<style>
  @page { size: A4; margin: 14mm; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: "Segoe UI", Tahoma, "Noto Naskh Arabic", Arial, sans-serif;
    color: #123c3c;
    font-size: 12px;
    line-height: 1.7;
  }
  header {
    border-bottom: 3px solid #e8a33d;
    padding-bottom: 10px;
    margin-bottom: 16px;
  }
  h1 { margin: 0 0 4px; font-size: 20px; }
  .meta { color: #5b7070; font-size: 11px; margin: 0; }
  .cards {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 16px;
  }
  .card {
    border: 1px solid #dfe7e7;
    border-radius: 8px;
    padding: 8px 12px;
    min-width: 130px;
  }
  .card .v { font-size: 16px; font-weight: 700; }
  .card .l { font-size: 10px; color: #5b7070; }
  table { width: 100%; border-collapse: collapse; font-size: 11px; }
  th, td {
    border: 1px solid #dfe7e7;
    padding: 5px 7px;
    text-align: center;
  }
  th { background: #eef3f3; font-weight: 700; }
  tbody tr:nth-child(even) { background: #f8fafa; }
  tbody tr.empty td { color: #9bb0b0; }
  tfoot td { background: #eef3f3; font-weight: 700; }
  thead { display: table-header-group; }
  tr { page-break-inside: avoid; }
  footer {
    margin-top: 14px;
    padding-top: 8px;
    border-top: 1px solid #dfe7e7;
    color: #5b7070;
    font-size: 10px;
  }
</style>
</head>
<body>
$bodyHtml
<script>
  window.addEventListener('load', function () {
    window.focus();
    window.print();
  });
</script>
</body>
</html>
''';

  final iframe = html.IFrameElement()
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..srcdoc = document;

  html.document.body!.append(iframe);
  Timer(const Duration(seconds: 60), iframe.remove);
}
