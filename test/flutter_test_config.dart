import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

/// A 1x1 transparent PNG - enough for any `NetworkImage` (map tiles,
/// dicebear avatar URLs, ...) to resolve successfully in tests without
/// depending on real network access.
const List<int> _transparentPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _FakeHttpHeaders extends Mock implements HttpHeaders {}

class _FakeHttpClientResponse extends Mock implements HttpClientResponse {}

class _FakeHttpClientRequest extends Mock implements HttpClientRequest {}

class _FakeHttpClient extends Mock implements HttpClient {}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _FakeHttpClient();
    final request = _FakeHttpClientRequest();
    final response = _FakeHttpClientResponse();
    final headers = _FakeHttpHeaders();

    when(() => client.getUrl(any())).thenAnswer((_) async => request);
    when(() => client.openUrl(any(), any())).thenAnswer((_) async => request);
    when(() => request.headers).thenReturn(headers);
    when(() => request.close()).thenAnswer((_) async => response);
    when(() => response.statusCode).thenReturn(HttpStatus.ok);
    when(() => response.contentLength).thenReturn(_transparentPng.length);
    when(() => response.isRedirect).thenReturn(false);
    when(
      () => response.compressionState,
    ).thenReturn(HttpClientResponseCompressionState.notCompressed);
    when(
      () => response.listen(
        any(),
        onDone: any(named: 'onDone'),
        onError: any(named: 'onError'),
        cancelOnError: any(named: 'cancelOnError'),
      ),
    ).thenAnswer((invocation) {
      final onData =
          invocation.positionalArguments[0] as void Function(List<int>);
      final onDone = invocation.namedArguments[#onDone] as void Function()?;
      return Stream<List<int>>.fromIterable([
        _transparentPng,
      ]).listen(onData, onDone: onDone);
    });

    return client;
  }
}

/// Flutter automatically loads this file (if present under `test/`) before
/// running any test in this directory, so every test gets a hermetic,
/// network-free `HttpClient` without needing per-file setup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  registerFallbackValue(Uri());
  registerFallbackValue('GET');
  HttpOverrides.global = _TestHttpOverrides();
  await testMain();
}
