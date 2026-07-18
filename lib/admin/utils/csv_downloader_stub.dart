/// Non-web fallback - the admin dashboard doesn't run on mobile, so this
/// only exists so the shared import graph compiles for Android/iOS too.
void downloadCsv(String filename, String content) {
  throw UnsupportedError(
    'CSV download is only available on the web admin dashboard.',
  );
}
