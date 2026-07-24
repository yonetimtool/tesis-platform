import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

// NetworkImage testte gercek ag'a cikar (400 -> test hatasi). Avatarli satirda
// gecerli 1x1 seffaf PNG donduren sahte istemci kurulur.
final _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

class _PngHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PngHttpRequest();
}

class _PngHttpRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _PngHttpHeaders();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
  @override
  Future<HttpClientResponse> close() async => _PngHttpResponse();
}

class _PngHttpResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([_transparentPng]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PngHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

void main() {
  testWidgets('personel listesinde avatarli satir + Personel ekle butonu',
      (tester) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fieldStaffProvider.overrideWith((ref) async => const [
                StaffMember(
                    id: 'u1', ad: 'Guard A', role: 'security',
                    isActive: true, avatarUrl: 'https://x/a.jpg'),
              ]),
        ],
        child: const MaterialApp(home: StaffScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Guard A'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.text('Personel ekle'), findsOneWidget);
    }, createHttpClient: (c) => _PngHttpClient());
  });
}
