/// Non-web fallback - the admin dashboard doesn't run on mobile, so this
/// only exists so the shared import graph compiles for Android/iOS too.
void printReportHtml(String documentTitle, String bodyHtml) {
  throw UnsupportedError(
    'PDF export is only available on the web admin dashboard.',
  );
}
