/// User-facing (Arabic) auth error, raised by [AuthRepository] instead of
/// leaking raw Supabase/Postgrest exceptions up to the UI layer.
class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);

  @override
  String toString() => message;
}
