/// (P252 §2) MAAS OTOMASYONU — mobil otomasyon kurallari ekrani (web
/// `p252-otomasyon-maas` ikizi): odeme gunu basina cumle, son calisma,
/// ac/kapat + otomatik onay ayni kaydi yazar, "simdi calistir", onay
/// bekleyen maaslar (tutar duzeltilerek tek onay + toplu onay); yetkisiz
/// (403) ise satir HIC cizilmez.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/otomasyon/presentation/otomasyon_kurallari_screen.dart';

import 'helpers/l10n_test_app.dart';

const _b1 = '11111111-1111-4111-8111-111111111111';
const _b2 = '22222222-2222-4222-8222-222222222222';

class _Tel implements HttpClientAdapter {
  _Tel({this.yasak = false, this.yazilan = 4});
  final bool yasak;
  final int yazilan;
  final cagrilar = <({String metot, String yol, Object? govde})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    cagrilar.add((metot: o.method, yol: o.path, govde: o.data));
    if (yasak && o.path.startsWith('/otomasyon/maas')) {
      return ResponseBody.fromString(
        jsonEncode({'error': {'code': 'forbidden', 'message': 'yasak'}}), 403,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/otomasyon/maas-ayari') => {
          'aktif': true, 'otomatik_onay': true,
          'gruplar': [
            {'odeme_gunu': 5, 'personel_sayisi': 3, 'aylik_toplam_kurus': 7500000},
          ],
          'personel_sayisi': 3, 'aylik_toplam_kurus': 7500000,
          'onay_bekleyenler': [
            {'id': _b1, 'tarih': '2026-10-05',
             'aciklama': 'Ahmet YILMAZ — Ekim 2026 maaşı (kısmi: 12/31 gün)', 'tutar_kurus': 967742},
            {'id': _b2, 'tarih': '2026-10-05',
             'aciklama': 'Ayşe KAYA — Ekim 2026 maaşı', 'tutar_kurus': 2500000},
          ],
        },
      ('GET', '/otomasyon/son-calismalar') => {'items': [
          {'kural': 'maas', 'tur': 'maas', 'zaman': '2026-10-05T03:00:00Z',
           'adet': 4, 'tutar_kurus': 9200000, 'durum': null},
        ]},
      ('POST', '/otomasyon/maaslar/calistir') => {'yazilan': yazilan, 'toplam_kurus': yazilan * 2300000},
      ('POST', '/otomasyon/maaslar/onayla') => {'onaylanan': 2, 'toplam_kurus': 3467742},
      ('GET', _) => {'items': <Object>[]},
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, _Tel tel) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: kap, child: l10nApp(const OtomasyonKurallariScreen())));
  await tester.pumpAndSettle();
  return tel;
}

String _metin(WidgetTester tester, String anahtar) =>
    tester.widget<Text>(find.byKey(Key(anahtar))).data!;

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('düz cümle + son çalışma', (tester) async {
    await _sur(tester, _Tel());
    expect(_metin(tester, 'kural-cumle-maas'),
        'Her ayın 5. günü 3 personelin maaşı (toplam ₺75.000,00) gidere yazılır.');
    expect(_metin(tester, 'kural-son-maas'),
        contains('4 personelin maaşı gidere yazıldı (toplam ₺92.000,00)'));
  });

  testWidgets('aç/kapat ve otomatik onay AYNI kaydı yazar', (tester) async {
    final tel = await _sur(tester, _Tel());
    await _dokun(tester, find.byKey(const Key('kural-anahtar-maas')));
    expect(tel.cagrilar.any((c) => c.metot == 'PATCH' &&
        c.yol == '/otomasyon/maas-ayari' && (c.govde as Map)['aktif'] == false), isTrue);
    await _dokun(tester, find.byKey(const Key('maas-otomatik-onay')));
    expect(tel.cagrilar.any((c) => c.metot == 'PATCH' &&
        (c.govde as Map)['otomatik_onay'] == false), isTrue);
  });

  testWidgets('şimdi çalıştır: sonuç; ikinci tetik: yazılacak yok', (tester) async {
    await _sur(tester, _Tel());
    await _dokun(tester, find.byKey(const Key('maas-calistir')));
    expect(find.text('4 maaş gideri yazıldı (toplam ₺92.000,00).'), findsOneWidget);
  });

  testWidgets('ikinci tetik yazmaz: hata değil bilgi', (tester) async {
    await _sur(tester, _Tel(yazilan: 0));
    await _dokun(tester, find.byKey(const Key('maas-calistir')));
    expect(find.textContaining('Yazılacak maaş yok'), findsOneWidget);
  });

  testWidgets('onay bekleyen: tutar DÜZELTİLEREK tek onay; toplu onay', (tester) async {
    final tel = await _sur(tester, _Tel());
    expect(find.byKey(const Key('maas-onay-bekleyenler')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('maas-tutar-$_b1')), '10.000');
    await _dokun(tester, find.byKey(const Key('maas-onayla-$_b1')));
    final tek = tel.cagrilar.singleWhere((c) => c.yol == '/finans/hareketler/$_b1/onayla');
    expect(tek.govde, {'tutar_kurus': 1000000});
    await _dokun(tester, find.byKey(const Key('maas-toplu-onay')));
    final toplu = tel.cagrilar.singleWhere((c) => c.yol == '/otomasyon/maaslar/onayla');
    expect(toplu.govde, {'ids': [_b1, _b2]});
  });

  testWidgets('yetkisiz (403): maaş satırı HİÇ çizilmez, hata da yok', (tester) async {
    await _sur(tester, _Tel(yasak: true));
    expect(find.byKey(const Key('kural-maas')), findsNothing);
    expect(find.byKey(const Key('maas-onay-bekleyenler')), findsNothing);
  });
}
