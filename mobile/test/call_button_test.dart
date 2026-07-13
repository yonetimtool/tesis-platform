import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/call/data/call_api.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';
import 'package:mobile/src/features/call/domain/call_models.dart';
import 'package:mobile/src/features/call/presentation/call_button.dart';

/// Sahte call API — verilen sonucu doner ya da ApiException firlatir (403/404).
class _FakeCallApi extends CallApi {
  _FakeCallApi({this.target, this.error}) : super(Dio());

  final CallTarget? target;
  final ApiException? error;
  final List<String> resolved = [];

  @override
  Future<CallTarget> resolve(String userId) async {
    resolved.add(userId);
    if (error != null) throw error!;
    return target!;
  }
}

/// Sahte cevirici — cevrilen tel: URI'lerini kaydeder (gercek dialer acilmaz).
class _FakeLauncher implements CallLauncher {
  final List<String> dialed = [];
  bool result = true;

  @override
  Future<bool> dial(String telUri) async {
    dialed.add(telUri);
    return result;
  }
}

const _target = CallTarget(
  userId: 'r-1',
  ad: 'Acme Sakin',
  role: 'resident',
  channel: 'phone',
  telefon: '+905551110000',
  telUri: 'tel:+905551110000',
);

Widget _app({required _FakeCallApi api, required _FakeLauncher launcher}) {
  return ProviderScope(
    overrides: [
      callApiProvider.overrideWithValue(api),
      callLauncherProvider.overrideWithValue(launcher),
    ],
    child: const MaterialApp(
      home: Scaffold(body: CallButton(userId: 'r-1', label: 'Sakini ara')),
    ),
  );
}

void main() {
  testWidgets('aranabilir (200): "Ara" butonu gorunur; dokununca tel: cevrilir',
      (tester) async {
    final api = _FakeCallApi(target: _target);
    final launcher = _FakeLauncher();
    await tester.pumpWidget(_app(api: api, launcher: launcher));
    await tester.pumpAndSettle();

    // /call-target cozuldu; etkin buton (etiket) gorunur.
    expect(api.resolved, ['r-1']);
    expect(find.text('Sakini ara'), findsOneWidget);
    expect(find.text('Aranamıyor'), findsNothing);

    await tester.tap(find.text('Sakini ara'));
    await tester.pumpAndSettle();
    // Cozulen numara ile cihaz ceviricisi (tel:) baslatildi — numara EKRANDA yok.
    expect(launcher.dialed, ['tel:+905551110000']);
    expect(find.text('+905551110000'), findsNothing);
  });

  testWidgets('rizasiz/numarasiz (404): sessiz "Aranamıyor"; buton yok',
      (tester) async {
    final api = _FakeCallApi(
      error: const ApiException(
        code: 'not_found',
        message: 'aranamiyor',
        statusCode: 404,
      ),
    );
    final launcher = _FakeLauncher();
    await tester.pumpWidget(_app(api: api, launcher: launcher));
    await tester.pumpAndSettle();

    expect(find.text('Aranamıyor'), findsOneWidget);
    expect(find.text('Sakini ara'), findsNothing);
  });

  testWidgets('yetkisiz yon (403): sessiz "Aranamıyor" (numara sizmaz)',
      (tester) async {
    final api = _FakeCallApi(
      error: const ApiException(
        code: 'forbidden',
        message: 'yetkisiz',
        statusCode: 403,
      ),
    );
    await tester.pumpWidget(_app(api: api, launcher: _FakeLauncher()));
    await tester.pumpAndSettle();
    expect(find.text('Aranamıyor'), findsOneWidget);
  });
}
