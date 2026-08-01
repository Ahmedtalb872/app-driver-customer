import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Falls back to DNS-over-HTTPS when the platform's normal DNS resolution
/// fails.
///
/// One test device hits `SocketException: Failed host lookup` on every
/// single request, on every network tried (mobile data and WiFi alike),
/// with every DNS provider tried (carrier default and an explicit
/// `dns.google` Private DNS) - yet the same device's browser resolves and
/// loads the exact same hostname instantly, every time, on both networks.
/// That split only makes sense if something on the network path is
/// interfering with plain DNS (port 53) and DNS-over-TLS (port 853, what
/// Android's Private DNS setting uses) specifically, while leaving
/// DNS-over-HTTPS alone - DoH traffic is indistinguishable from ordinary
/// HTTPS on port 443, which is exactly what Chrome's on-by-default "Secure
/// DNS" uses and why it never breaks even when the app does.
///
/// This only ever engages as a fallback: [InternetAddress.lookup] is tried
/// first and used as-is on any device where it already works (the vast
/// majority), so this can't change behavior for anyone not already
/// completely unable to connect.
class DohFallbackHttpOverrides extends HttpOverrides {
  /// Cloudflare's DoH endpoint, queried by IP so resolving *it* never hits
  /// the same broken path - `1.1.1.1` needs no DNS lookup at all.
  static const _dohIp = '1.1.1.1';
  static const _dohHost = 'cloudflare-dns.com';

  final _cache = <String, InternetAddress>{};

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (
      Uri uri,
      String? proxyHost,
      int? proxyPort,
    ) async {
      final address = await _resolve(uri.host, context);
      final rawSocket = await Socket.connect(address, uri.port);
      if (uri.scheme != 'https') {
        return ConnectionTask<Socket>.fromSocket(
          rawSocket,
          () => rawSocket.destroy(),
        );
      }
      final secureSocket = await SecureSocket.secure(
        rawSocket,
        host: uri.host,
        context: context,
      );
      return ConnectionTask<Socket>.fromSocket(
        secureSocket,
        () => secureSocket.destroy(),
      );
    };
    return client;
  }

  Future<InternetAddress> _resolve(String host, SecurityContext? context) async {
    final cached = _cache[host];
    if (cached != null) return cached;

    try {
      final results = await InternetAddress.lookup(host);
      if (results.isNotEmpty) {
        _cache[host] = results.first;
        return results.first;
      }
    } on SocketException {
      // Fall through to the DoH fallback below.
    }

    final resolved = await _resolveViaDoh(host, context);
    _cache[host] = resolved;
    return resolved;
  }

  Future<InternetAddress> _resolveViaDoh(
    String host,
    SecurityContext? context,
  ) async {
    final rawSocket = await Socket.connect(_dohIp, 443);
    final secureSocket = await SecureSocket.secure(
      rawSocket,
      host: _dohHost,
      context: context,
    );
    try {
      final path = '/dns-query?name=$host&type=A';
      secureSocket.write(
        'GET $path HTTP/1.1\r\n'
        'Host: $_dohHost\r\n'
        'Accept: application/dns-json\r\n'
        'Connection: close\r\n\r\n',
      );
      await secureSocket.flush();

      final response = await secureSocket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      final bodyStart = response.indexOf('\r\n\r\n');
      if (bodyStart == -1) {
        throw const SocketException('DoH: malformed HTTP response');
      }
      final body = response.substring(bodyStart + 4);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final answers = json['Answer'] as List<dynamic>?;
      final ip = answers
          ?.map((a) => a as Map<String, dynamic>)
          .firstWhere(
            (a) => a['type'] == 1, // A record
            orElse: () => const {},
          )['data'] as String?;
      if (ip == null || ip.isEmpty) {
        throw SocketException('DoH: no A record for $host');
      }
      return InternetAddress(ip);
    } finally {
      unawaited(secureSocket.close());
    }
  }
}
