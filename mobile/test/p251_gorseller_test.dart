/// (P251 §5) ORTAK GORSEL — gosterim (kucuk/buyuk, yoksa duzgun gorunum)
/// ve secici (yukle -> anahtar, kaldir -> null, bekliyor). Rezervasyon
/// alani modeli gorseli okur ve govdeye yazar.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/core/ui/gorsel_secici.dart';
import 'package:mobile/src/core/ui/icerik_gorseli.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;

import 'helpers/l10n_test_app.dart';

class _Secici extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(Uint8List.fromList(List<int>.filled(8, 1)),
          name: 'havuz.jpg', path: '/tmp/p251-yok.jpg', mimeType: 'image/jpeg');
}

class _Yukleyici implements GorselYukleyici {
  int cagri = 0;
  @override
  Future<String> yukle(XFile dosya) async {
    cagri++;
    return 'tenant/tasks/havuz.jpg';
  }
}

void main() {
  testWidgets('kucuk: gorsel yoksa ikon kutusu; buyuk: hic cizilmez', (tester) async {
    await tester.pumpWidget(l10nApp(const Scaffold(body: Column(children: [
      IcerikGorseli(url: null, boy: IcerikGorseliBoy.kucuk, tur: IcerikTuru.alan),
      IcerikGorseli(url: null, boy: IcerikGorseliBoy.buyuk, tur: IcerikTuru.alan),
    ]))));
    expect(find.byKey(const Key('icerik-gorseli-yok')), findsOneWidget);
    expect(find.byKey(const Key('icerik-gorseli-buyuk')), findsNothing);
  });

  testWidgets('yuklenemeyen gorsel: kucuk ikon kutusuna doner, buyuk kaybolur', (tester) async {
    await tester.pumpWidget(l10nApp(const Scaffold(body: Column(children: [
      IcerikGorseli(url: 'http://yok.invalid/a.png', boy: IcerikGorseliBoy.kucuk, tur: IcerikTuru.etkinlik),
      IcerikGorseli(url: 'http://yok.invalid/b.png', boy: IcerikGorseliBoy.buyuk, tur: IcerikTuru.etkinlik),
    ]))));
    // Testte ag kapali: Image.network hata verir.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('icerik-gorseli-yok')), findsOneWidget);
    expect(find.byKey(const Key('icerik-gorseli-buyuk')), findsNothing);
  });

  testWidgets('secici: galeriden sec -> anahtar; kaldir -> mevcut silinir', (tester) async {
    final yukleyici = _Yukleyici();
    final secimler = <GorselSecim>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        imagePickerProvider.overrideWithValue(_Secici()),
        gorselYukleyiciProvider.overrideWithValue(yukleyici),
      ],
      child: l10nApp(Scaffold(
        body: SingleChildScrollView(
          child: GorselSecici(
            mevcutUrl: null,
            tur: IcerikTuru.alan,
            onDegisti: secimler.add,
          ),
        ),
      )),
    ));
    await tester.tap(find.byKey(const Key('gorsel-galeri')));
    await tester.pumpAndSettle();
    expect(yukleyici.cagri, 1);
    expect(secimler.last.fotoKey, 'tenant/tasks/havuz.jpg');
    expect(secimler.last.bekliyor, isFalse);
    final govde = <String, dynamic>{};
    secimler.last.govdeye(govde);
    expect(govde, {'foto_key': 'tenant/tasks/havuz.jpg'});
  });

  test('alan modeli gorseli okur; taslak gorseli yazar (yeni / kaldir / dokunulmadi)', () {
    final a = OrtakAlan.fromJson({
      'id': 'x', 'ad': 'Havuz', 'aktif': true, 'created_at': '2026-10-02T00:00:00Z',
      'foto_key': 't/k.png', 'foto_url': 'http://minio/k.png',
    });
    expect(a.fotoUrl, 'http://minio/k.png');
    expect(const OrtakAlanDraft(ad: 'H', gorsel: GorselSecim(fotoKey: 'k')).toJson()['foto_key'], 'k');
    final kaldir = const OrtakAlanDraft(ad: 'H', gorsel: GorselSecim(kaldirildi: true)).toJson();
    expect(kaldir.containsKey('foto_key'), isTrue);
    expect(kaldir['foto_key'], isNull);
    expect(const OrtakAlanDraft(ad: 'H').toJson().containsKey('foto_key'), isFalse);
  });
}
