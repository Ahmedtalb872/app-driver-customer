import 'package:url_launcher/url_launcher.dart';

/// Opens the device's native phone dialer pre-filled with [phone].
class PhoneCaller {
  static Future<bool> call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    return launchUrl(uri);
  }
}
