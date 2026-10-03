import 'package:http/http.dart';

/// Web (and any other platform without `dart:io`) never gets a Cronet
/// client - `supabase_flutter` falls back to its own default client.
Client? buildAndroidCronetHttpClient() => null;
