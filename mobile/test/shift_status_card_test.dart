import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/shift_status_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

// NetworkImage testte gercek ag'a cikar (400 -> test hatasi). Yalniz avatar
// testinde gecerli 1x1 seffaf PNG donduren sahte istemci kurulur.
final _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

class _PngHttpClient implements HttpClient {
  @override
  bool autoUncompress = true; // NetworkImage bunu false'a ceker
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
  group('ShiftStatusCard — "Vardiya Durumu" kisi karti (referans)', () {
    testWidgets('vardiya adi + saat araligi + gorevli sayisi gosterir',
        (tester) async {
      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Sabah Vardiyası',
        subtitle: '06:00 - 14:00',
        status: ShiftStatus.aktif,
        footer: '2 Görevli',
      )));
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('2 Görevli'), findsOneWidget);
    });

    testWidgets('durum cipi etiketi: AKTİF / PLANLANDI / YÖNETİCİ',
        (tester) async {
      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Sabah',
        subtitle: '06:00 - 14:00',
        status: ShiftStatus.aktif,
        footer: '2 Görevli',
      )));
      expect(find.text('AKTİF'), findsOneWidget);

      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Gece',
        subtitle: '22:00 - 06:00',
        status: ShiftStatus.planlandi,
        footer: '2 Görevli',
      )));
      expect(find.text('PLANLANDI'), findsOneWidget);

      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Yönetici',
        subtitle: 'Kerem Aşçı',
        status: ShiftStatus.yonetici,
        footer: 'Online',
        online: true,
      )));
      expect(find.text('YÖNETİCİ'), findsOneWidget);
      expect(find.text('Kerem Aşçı'), findsOneWidget);
    });

    testWidgets('avatarUrl verilirse resimli avatar cizilir', (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_wrap(const ShiftStatusCard(
          title: 'Sabah', subtitle: '06:00 - 14:00',
          status: ShiftStatus.aktif, footer: '2 Görevli',
          avatarUrl: 'https://example.com/a.jpg',
        )));
        await tester.pumpAndSettle();
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(avatar.backgroundImage, isA<NetworkImage>());
      }, createHttpClient: (c) => _PngHttpClient());
    });
  });
}
