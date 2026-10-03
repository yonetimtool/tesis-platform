/// (P253 Asama 1) MOBIL FINANS DEFTERI + §C kurali.
///
/// Taklit HTTP ADAPTORUNDE: istek govdesini kuran katman (API istemcisi)
/// da olculur — repo/API duzeyinde taklit, govdedeki `aciklama` ya da
/// `tip` hatasini goremezdi.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/ui/finans_onay.dart';
import 'package:mobile/src/features/finans/data/finans_api.dart';
import 'package:mobile/src/features/finans/presentation/finans_defteri_screen.dart';
import 'package:mobile/src/features/finans/presentation/gider_screen.dart';
import 'package:mobile/src/features/finans/presentation/otomasyon_gunlugu_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Adaptor implements HttpClientAdapter {
  final List<RequestOptions> istekler = [];

  Map<String, dynamic> _hareket(String id, {required String durum}) => {
        'id': id,
        'tip': 'gider',
        'yon': 'cikis',
        'tutar_kurus': 125000,
        'tarih': '2026-10-01',
        'durum': durum,
        'kasa_ad': 'Merkez Kasa',
        'user_ad': 'Ahmet YILMAZ',
        'unit_no': 'A-12',
        'belge_no': 'GDR-1',
        'created_at': '2026-10-01T10:00:00Z',
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(o);
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/finans/ozet') => {
          'borclandirilan_ay_kurus': 1000000,
          'tahsil_edilen_ay_kurus': 750000,
          'acik_borc_kurus': 250000,
          'kasa_toplam_kurus': 4200000,
          'icra_acik_dosya': 1,
          'onay_bekleyen_adet': 1,
          'personel_gideri_ay_kurus': 2500000,
        },
      ('GET', '/finans/kasa-bakiyeleri') => {
          'items': [
            {
              'kasa_id': 'k1', 'kod': 'MRK', 'ad': 'Merkez Kasa',
              'bakiye_kurus': 4200000, 'bekleyen_cikis_kurus': 125000,
            },
          ],
          'genel_toplam_kurus': 4200000,
          'bekleyen_cikis_toplam_kurus': 125000,
        },
      ('GET', '/finans/hareketler') => {
          'items': [_hareket('h1', durum: 'onay_bekliyor')],
          'meta': {'total': 1, 'limit': 30, 'offset': 0},
        },
      ('POST', '/finans/hareketler/h1/reddet') => _hareket('h1', durum: 'iptal'),
      ('POST', '/finans/hareketler/h1/onayla') => _hareket('h1', durum: 'odendi'),
      ('GET', '/kasalar') => {
          'items': [{'id': 'k1', 'ad': 'Merkez Kasa'}],
        },
      ('GET', '/gelir-gider-tanimlari') => {'items': []},
      ('GET', '/firmalar') => {
          'items': [{'id': 'f1', 'ad': 'Temizlik AŞ'}],
        },
      ('POST', '/finans/hareketler') => {
          'items': [_hareket('yeni', durum: 'odendi')],
        },
      ('GET', '/otomasyon-gunlugu') => {
          'items': [
            {
              'id': 'g1', 'tur': 'maas', 'calisma_zamani': '2026-10-01T06:00:00Z',
              'donem': '2026-10', 'adet': 3, 'tutar_kurus': 7500000, 'sonuc': {},
            },
          ],
          'meta': {'total': 1, 'limit': 50, 'offset': 0},
        },
      ('GET', '/finans/hatirlatma-gecmisi') => {
          'gonderilen': 4, 'okunan': 1,
          'items': [
            {'id': 'n1', 'ad': 'Ayşe KAYA', 'gonderim_zamani': '2026-10-01T08:00:00Z',
             'okundu': true, 'tutar': '1.250,00 TL'},
          ],
          'meta': {'total': 1, 'limit': 50, 'offset': 0},
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> yazilan(String yol) =>
      istekler.where((i) => i.method == 'POST' && i.path == yol);
}

Future<_Adaptor> _kur(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final adaptor = _Adaptor();
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adaptor;
  await tester.pumpWidget(ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: l10nApp(ekran),
  ));
  await tester.pumpAndSettle();
  return adaptor;
}

void main() {
  testWidgets('OZET: sunucunun ozet ve kasa bakiyeleri (bekleyen cikis ayri)',
      (tester) async {
    await _kur(tester, const FinansDefteriScreen());
    expect(find.byKey(const Key('fin-ozet')), findsOneWidget);
    expect(find.text(tlTutar(750000)), findsOneWidget);
    expect(find.text('Onay bekleyen'), findsOneWidget);
    expect(find.text('Merkez Kasa'), findsOneWidget);
    expect(find.text('Bekleyen çıkış: ${tlTutar(125000)}'), findsOneWidget);
    expect(find.byKey(const Key('fin-genel-toplam')), findsOneWidget);
  });

  testWidgets('§C RED: hedef + tutar yazili, sebepsiz PASIF, sebep GOVDEDE',
      (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin-hareket-h1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin-reddet')));
    await tester.pumpAndSettle();

    expect(find.text('A-12 · Ahmet YILMAZ · GDR-1'), findsWidgets);
    expect(find.byKey(const Key('finans-onay-tutar')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-tutar'))).data,
        tlTutar(125000));
    expect(find.textContaining('GERİ ALINAMAZ'), findsOneWidget);
    final dugme = find.byKey(const Key('finans-onay-dugme'));
    expect(tester.widget<FilledButton>(dugme).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('finans-onay-sebep')), ' ab ');
    await tester.pump();
    expect(tester.widget<FilledButton>(dugme).onPressed, isNull,
        reason: 'kirpilmis ${sebepAsgari - 1} karakter yetmez');
    await tester.enterText(find.byKey(const Key('finans-onay-sebep')), '  Fatura eksik ');
    await tester.pump();
    await tester.tap(dugme);
    await tester.pumpAndSettle();

    final red = a.yazilan('/finans/hareketler/h1/reddet').single;
    expect(red.data, {'aciklama': 'Fatura eksik'});
    expect(find.text('Hareket reddedildi.'), findsOneWidget);
  });

  testWidgets('§C ONAY: tutar + hedef + geri alinamazlik notu; sonra POST',
      (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin-hareket-h1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin-onayla')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('finans-onay-sebep')), findsNothing);
    expect(find.textContaining('ters kayıtla'), findsOneWidget);
    // Vazgec -> istek YOK.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/hareketler/h1/onayla'), isEmpty);
    await tester.tap(find.byKey(const Key('fin-onayla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/hareketler/h1/onayla'), hasLength(1));
  });

  test('HAREKET LISTESI web ile ayni suzgecleri sunucuya tasir', () async {
    final a = _Adaptor();
    final api = FinansApi(Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a);
    await api.hareketler(tip: 'gider', kasaId: 'k1', limit: 30, offset: 60);
    expect(a.istekler.single.queryParameters,
        {'tip': 'gider', 'kasa_id': 'k1', 'limit': 30, 'offset': 60});
  });

  testWidgets('GELIR gider ekranindan; tarih + belge no + firma govdede',
      (tester) async {
    final a = await _kur(tester, const GiderScreen());
    await tester.tap(find.text('Gelir'));
    await tester.pumpAndSettle();
    // Gelirde onay akisi yok.
    expect(find.byKey(const Key('gider-onay-bekliyor')), findsNothing);
    await tester.enterText(find.byKey(const Key('gider-tutar')), '1.250,00');
    await tester.enterText(find.byKey(const Key('gider-belge-no')), 'GLR-7');
    await tester.tap(find.byKey(const Key('gider-firma')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temizlik AŞ').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gider-kaydet')));
    await tester.tap(find.byKey(const Key('gider-kaydet')));
    await tester.pumpAndSettle();
    final satir = (a.yazilan('/finans/hareketler').single.data as Map)['satirlar'][0] as Map;
    expect(satir['tip'], 'gelir');
    expect(satir['tutar_kurus'], 125000);
    expect(satir['belge_no'], 'GLR-7');
    expect(satir['firma_id'], 'f1');
    expect(satir['durum'], 'odendi');
    expect(satir['tarih'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(find.text('Gelir kaydedildi.'), findsOneWidget);
  });

  testWidgets('BOS BELGE NO gonderilmez (sunucu seriyi uretir)', (tester) async {
    final a = await _kur(tester, const GiderScreen());
    await tester.enterText(find.byKey(const Key('gider-tutar')), '10');
    await tester.ensureVisible(find.byKey(const Key('gider-kaydet')));
    await tester.tap(find.byKey(const Key('gider-kaydet')));
    await tester.pumpAndSettle();
    final satir = (a.yazilan('/finans/hareketler').single.data as Map)['satirlar'][0] as Map;
    expect(satir.containsKey('belge_no'), isFalse);
    expect(satir['tip'], 'gider');
  });

  testWidgets('OTOMASYON GUNLUGU ve HATIRLATMA GECMISI', (tester) async {
    await _kur(tester, const OtomasyonGunluguScreen());
    expect(find.text('Maaş gideri'), findsOneWidget);
    expect(find.textContaining('3 kayıt'), findsOneWidget);
    await tester.tap(find.text('Gönderilen hatırlatmalar'));
    await tester.pumpAndSettle();
    expect(find.text('4 gönderildi · 1 okundu'), findsOneWidget);
    expect(find.text('Ayşe KAYA'), findsOneWidget);
  });
}
