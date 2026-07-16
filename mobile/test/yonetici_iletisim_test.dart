import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';
import 'package:mobile/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart';
import 'package:mobile/src/features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart';

class _FakeLauncher implements CallLauncher {
  String? dialed;

  @override
  Future<bool> dial(String telUri) async {
    dialed = telUri;
    return true;
  }
}

void main() {
  testWidgets('Yoneticiyi Ara -> tel: URI ceviriciye gider', (tester) async {
    final fake = _FakeLauncher();
    const kart = YoneticiKart(
      userId: 'u1',
      adSoyad: 'Ayse Yilmaz',
      telefon: '+90 532 111 22 01',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [callLauncherProvider.overrideWithValue(fake)],
      child: const MaterialApp(
        home: Scaffold(body: YoneticiKartTile(kart: kart)),
      ),
    ));

    await tester.tap(find.text('Yöneticiyi Ara'));
    await tester.pump();

    expect(fake.dialed, 'tel:+905321112201');
  });

  testWidgets('telefonu olmayan yoneticide arama butonu yok', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: YoneticiKartTile(
            kart: YoneticiKart(userId: 'u2', adSoyad: 'Numarasiz'),
          ),
        ),
      ),
    ));
    expect(find.text('Yöneticiyi Ara'), findsNothing);
  });
}
