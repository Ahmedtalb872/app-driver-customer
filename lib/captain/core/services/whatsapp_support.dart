import 'package:url_launcher/url_launcher.dart';

/// Opens a WhatsApp chat with the support/admin number, used wherever a
/// captain might be stuck waiting (e.g. account under review) and needs a
/// human to reach out to.
class WhatsAppSupport {
  static const String supportPhone = '22220522064';

  static Future<bool> contactSupport({String? message}) async {
    final query = message != null
        ? '?text=${Uri.encodeComponent(message)}'
        : '';
    final uri = Uri.parse('https://wa.me/$supportPhone$query');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
