/// (P250 §9) OTOMASYON KURALLARI — mobil: düz cümle, aç/kapat, son çalışma,
/// "bugün çalışsaydı", dört adımlı sihirbaz + sunucu önizlemesi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/otomasyon/presentation/kural_cumlesi.dart';
import 'package:mobile/src/features/otomasyon/presentation/kural_sihirbazi_screen.dart';
import 'package:mobile/src/features/otomasyon/presentation/otomasyon_kurallari_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Cagri {
  _Cagri(this.metot, this.yol, this.govde);
  final String metot;
  final String yol;
  final Object? govde;
}

class _Tel implements HttpClientAdapter {
  final cagrilar = <_Cagri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    cagrilar.add(_Cagri(o.method, o.path, o.data));
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/aidat-planlari') => {'items': [
          {'id': 'p1', 'ad': 'Aidat', 'dagitim': 'daire_basina', 'tutar_kurus': 120000,
           'toplam_tutar_kurus': null, 'tahakkuk_gunu': 1, 'vade_gun': 10, 'aktif': true,
           'ertelenen_donem': null},
        ]},
      ('GET', '/duzenli-giderler') => {'items': [
          {'id': 'g1', 'ad': 'Kapıcı maaşı', 'tutar_kurus': 1500000, 'periyot': 'aylik',
           'sonraki_tarih': '2026-11-05', 'otomatik_onay': false, 'aktif': false},
        ]},
      ('GET', '/hatirlatma-ayari') => {
          'aktif': true, 'vade_oncesi_gun': 0, 'kademeler': [3], 'metin': null,
          'eposta': false, 'ilk_gun': 3, 'tekrar_sayisi': 1, 'aralik_gun': 7},
      ('GET', '/borclandirma/gecikme-ayari') => {'gecikme_aylik_yuzde': 5, 'gecikme_uygula': true},
      ('GET', '/otomasyon/son-calismalar') => {'items': [
          {'kural': 'p1', 'tur': 'aidat_tahakkuk', 'zaman': '2026-10-01T03:00:00Z',
           'adet': 47, 'tutar_kurus': 5640000, 'durum': null},
        ]},
      ('GET', '/hatirlatma-ayari/onizleme') => {'adet': 12, 'toplam_kurus': 900000, 'atlanan': 0},
      ('GET', '/borclandirma/gecikme-faizi/onizleme') => {
          'toplam_fark_kurus': 25000,
          'items': [{'fark_kurus': 15000}, {'fark_kurus': 10000}, {'fark_kurus': 0}]},
      ('POST', '/aidat-planlari/onizleme') => {
          'adet': 47, 'toplam_kurus': 5640000, 'atlanan': 2, 'ilk_tarih': '2026-10-05'},
      ('GET', '/gelir-gider-tanimlari') => {'items': [{'id': 't1', 'ad': 'Aidat'}]},
      ('GET', '/kasalar') => {'items': [{'id': 'k1', 'ad': 'Banka'}]},
      _ => <String, dynamic>{'id': 'yeni'},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: kap, child: l10nApp(ekran)));
  await tester.pumpAndSettle();
  return tel;
}

String _metin(WidgetTester tester, String anahtar) =>
    tester.widget<Text>(find.byKey(Key(anahtar))).data!;

void main() {
  testWidgets('her kural düz cümle + son çalışma + bugün çalışsaydı', (tester) async {
    await _sur(tester, const OtomasyonKurallariScreen());
    expect(_metin(tester, 'kural-cumle-p1'),
        contains('Her ayın 1. günü tüm dairelere daire başına ₺1.200,00 “Aidat” borcu'));
    expect(_metin(tester, 'kural-son-p1'), contains('47 daireye toplam ₺56.400,00 borç yazıldı'));
    expect(_metin(tester, 'kural-cumle-g1'), contains('Her ay “Kapıcı maaşı” için ₺15.000,00 ödeme kaydı'));
    expect(_metin(tester, 'kural-son-g1'), 'Henüz çalışmadı.');
    await tester.scrollUntilVisible(find.byKey(const Key('kural-gecikme_faizi')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(_metin(tester, 'kural-bugun-borc_hatirlatma'), contains('12 kişiye hatırlatma giderdi'));
    expect(_metin(tester, 'kural-cumle-gecikme_faizi'), contains('%5 gecikme faizi'));
    expect(_metin(tester, 'kural-bugun-gecikme_faizi'), contains('2 borca toplam ₺250,00 faiz'));
    for (final terim in ['tahakkuk', 'kademe', 'periyot', 'dağıtım']) {
      expect(find.textContaining(terim), findsNothing);
    }
  });

  testWidgets('aç/kapat kuralın kendi kaydına yazar', (tester) async {
    final tel = await _sur(tester, const OtomasyonKurallariScreen());
    await tester.tap(find.byKey(const Key('kural-anahtar-g1')));
    await tester.pumpAndSettle();
    final p = tel.cagrilar.firstWhere((c) => c.metot == 'PATCH');
    expect(p.yol, '/duzenli-giderler/g1');
    expect(p.govde, {'aktif': true});
    await tester.scrollUntilVisible(find.byKey(const Key('kural-anahtar-gecikme_faizi')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('kural-anahtar-gecikme_faizi')));
    await tester.pumpAndSettle();
    final g = tel.cagrilar.lastWhere((c) => c.metot == 'PATCH');
    expect(g.yol, '/borclandirma/gecikme-ayari');
    expect(g.govde, {'gecikme_uygula': false});
  });

  testWidgets('sihirbaz: ne zaman → kime → ne → önizleme (sunucu) → kaydet', (tester) async {
    final tel = await _sur(tester, KuralSihirbaziScreen(bugun: DateTime(2026, 10, 3)));
    expect(_metin(tester, 'sihirbaz-baslik'), 'Ne zaman?');
    await tester.enterText(find.byKey(const Key('sihirbaz-gun')), '5');
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'sihirbaz-baslik'), 'Kime?');
    // Seçmeden ilerlenmez.
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sihirbaz-hata')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sihirbaz-tur-borc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'sihirbaz-baslik'), 'Ne yapılsın?');
    await tester.enterText(find.byKey(const Key('sihirbaz-ad')), 'Aylık aidat');
    await tester.tap(find.byKey(const Key('sihirbaz-kalem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aidat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sihirbaz-tutar')), '1200');
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();

    expect(_metin(tester, 'sihirbaz-baslik'), 'Önizleme');
    final o = tel.cagrilar.firstWhere((c) => c.yol == '/aidat-planlari/onizleme');
    expect(o.metot, 'POST');
    expect(o.govde, containsPair('tahakkuk_gunu', 5));
    expect(o.govde, containsPair('tutar_kurus', 120000));
    expect(o.govde, containsPair('gelir_gider_tanim_id', 't1'));
    expect(_metin(tester, 'sihirbaz-cumle'), contains('Her ayın 5. günü'));
    expect(_metin(tester, 'sihirbaz-bugun'),
        'Bu kural bugün çalışsaydı 47 daireye toplam ₺56.400,00 borç yazılırdı.');
    expect(find.text('2 dairenin tutarı belirlenemediği için atlanırdı.'), findsOneWidget);
    expect(tel.cagrilar.where((c) => c.metot == 'POST' && c.yol == '/aidat-planlari'), isEmpty);

    await tester.tap(find.byKey(const Key('sihirbaz-kaydet')));
    await tester.pumpAndSettle();
    expect(tel.cagrilar.where((c) => c.metot == 'POST' && c.yol == '/aidat-planlari'), hasLength(1));
  });

  testWidgets('sihirbaz: aylık değilse borç seçilemez; ödeme kaydı kurulur', (tester) async {
    final tel = await _sur(tester, KuralSihirbaziScreen(bugun: DateTime(2026, 10, 3)));
    await tester.tap(find.byKey(const Key('sihirbaz-siklik-uc_aylik')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sihirbaz-ilk-tarih')));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(find.text('Dairelere borç yazma yalnız “Her ay” seçildiğinde kullanılabilir.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sihirbaz-tur-borc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'sihirbaz-baslik'), 'Kime?'); // borç seçilemedi
    await tester.tap(find.byKey(const Key('sihirbaz-tur-gider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sihirbaz-ad')), 'Asansör bakımı');
    await tester.enterText(find.byKey(const Key('sihirbaz-tutar')), '3000');
    await tester.tap(find.byKey(const Key('sihirbaz-ileri')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'sihirbaz-cumle'), contains('Üç ayda bir “Asansör bakımı” için ₺3.000,00'));
    await tester.tap(find.byKey(const Key('sihirbaz-kaydet')));
    await tester.pumpAndSettle();
    final p = tel.cagrilar.firstWhere((c) => c.metot == 'POST' && c.yol == '/duzenli-giderler');
    expect(p.govde, containsPair('periyot', 'uc_aylik'));
    expect(p.govde, containsPair('sonraki_tarih', '2026-10-03'));
    expect(p.govde, containsPair('tutar_kurus', 300000));
  });

  test('ilk aylık tarih', () {
    expect(ilkAylikTarih(5, DateTime(2026, 10, 3)), DateTime(2026, 10, 5));
    expect(ilkAylikTarih(5, DateTime(2026, 10, 6)), DateTime(2026, 11, 5));
    expect(ilkAylikTarih(1, DateTime(2026, 12, 20)), DateTime(2027, 1, 1));
  });
}
