/// (P253 Asama 2) MOBIL FINANS DUZELTMELERI + hareket aramasi, §C kurali.
///
/// Taklit HTTP ADAPTORUNDE: govdeyi kuran katman (API istemcisi) da olculur.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/finans/presentation/borclular_screen.dart';
import 'package:mobile/src/features/finans/presentation/finans_defteri_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Adaptor implements HttpClientAdapter {
  final List<RequestOptions> istekler = [];

  Map<String, dynamic> _h(String id, String tip, {String yon = 'giris', int tutar = 100000, String? grup}) => {
        'id': id,
        'tip': tip,
        'yon': yon,
        'tutar_kurus': tutar,
        'tarih': '2026-10-01',
        'durum': 'odendi',
        'kasa_ad': 'Merkez Kasa',
        'user_ad': 'Ayşe KAYA',
        'unit_no': 'B-3',
        'belge_no': 'THS-7',
        'virman_grup_id': grup,
        'created_at': '2026-10-01T10:00:00Z',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istekler.add(o);
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/finans/ozet') => <String, dynamic>{},
      ('GET', '/finans/kasa-bakiyeleri') => {'items': [], 'genel_toplam_kurus': 0},
      ('GET', '/finans/hareketler') => {
          'items': [_h('t1', 'tahsilat')],
          'meta': {'total': 1},
        },
      ('GET', '/kasalar') => {
          'items': [
            {'id': 'k1', 'ad': 'Merkez Kasa'},
            {'id': 'k2', 'ad': 'Banka'},
          ],
        },
      ('POST', '/finans/hareketler/t1/iptal') => _h('ipt', 'iptal', yon: 'cikis'),
      ('POST', '/finans/iade') => _h('iade1', 'iade', yon: 'cikis', tutar: 40000),
      ('POST', '/finans/hareketler/iade1/iptal') => _h('ipt2', 'iptal'),
      ('POST', '/finans/virman') => {
          'items': [
            _h('v1', 'virman', yon: 'cikis', tutar: 500000, grup: 'g'),
            _h('v2', 'virman', tutar: 500000, grup: 'g'),
          ],
        },
      ('POST', '/finans/hareketler/v1/iptal') => _h('ipt3', 'iptal'),
      ('GET', '/finans/yaslandirma') => {
          'kovalar': [
            {
              'kova': '0-30', 'daire': 2, 'kalan_kurus': 300000,
              'daireler': [
                {'unit_id': 'u1', 'unit_no': 'A-1', 'kalan_kurus': 100000, 'en_eski_gun': 10,
                 'borclu_user_id': 'p1', 'borclu_ad': 'Ali VELİ'},
                {'unit_id': 'u2', 'unit_no': 'A-2', 'kalan_kurus': 200000, 'en_eski_gun': 20},
              ],
            },
          ],
          'toplam_kalan_kurus': 300000,
          'toplam_daire': 2,
        },
      ('GET', '/finans/tahsilat-gostergesi') => {'donem': '2026-10'},
      ('POST', '/finans/borclulara/faiz-affi') => {'affedilen_kalem': 3, 'toplam_kurus': 4500},
      ('POST', '/finans/borclulara/odeme-plani') => {'daire': 2, 'guncellenen_borc': 5},
      ('POST', '/finans/tahsilat/toplu') => {
          'items': [_h('tt1', 'tahsilat'), _h('tt2', 'tahsilat')],
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> yazilan(String yol) =>
      istekler.where((i) => i.method == 'POST' && i.path == yol).toList();
}

Future<_Adaptor> _kur(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final a = _Adaptor();
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;
  await tester.pumpWidget(ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: l10nApp(ekran),
  ));
  await tester.pumpAndSettle();
  return a;
}

Future<void> _hareketler(WidgetTester tester) async {
  await tester.tap(find.text('Hareketler'));
  await tester.pumpAndSettle();
}

/// §C diyalogu: sebep yaz ve onayla.
Future<void> _sebeple(WidgetTester tester, String sebep) async {
  final dugme = find.byKey(const Key('finans-onay-dugme'));
  expect(tester.widget<FilledButton>(dugme).onPressed, isNull, reason: 'sebepsiz PASIF');
  await tester.enterText(find.byKey(const Key('finans-onay-sebep')), sebep);
  await tester.pump();
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ARAMA + DURUM sunucu sorgusunda (q, durum)', (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await _hareketler(tester);
    await tester.enterText(find.byKey(const Key('liste-ara')), 'şahin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-sirala-suz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-suzgec-durum-onay_bekliyor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-uygula')));
    await tester.pumpAndSettle();
    final son = a.istekler.lastWhere((i) => i.path == '/finans/hareketler');
    expect(son.queryParameters['q'], 'şahin');
    expect(son.queryParameters['durum'], 'onay_bekliyor');
  });

  testWidgets('IPTAL: hedef + tutar, sebep ZORUNLU, sebep GOVDEDE', (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await _hareketler(tester);
    await tester.tap(find.byKey(const Key('fin-hareket-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-iptal')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-hedef'))).data, contains('B-3'));
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-tutar'))).data, contains('1.000,00'));
    await _sebeple(tester, 'Yanlış daireye yazıldı');
    expect(a.yazilan('/finans/hareketler/t1/iptal').single.data, {'aciklama': 'Yanlış daireye yazıldı'});
  });

  testWidgets('IADE kismi tutar + GERI AL (sebep istenir, iade ters kayitlanir)', (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await _hareketler(tester);
    await tester.tap(find.byKey(const Key('fin-hareket-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-iade')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fdz-tutar')), '400');
    await tester.tap(find.byKey(const Key('fdz-form-kaydet')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-tutar'))).data, contains('400,00'));
    expect(a.yazilan('/finans/iade'), isEmpty, reason: 'onaysiz istek YOK');
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/iade').single.data, {'hareket_id': 't1', 'tutar_kurus': 40000});
    await tester.tap(find.byKey(const Key('fdz-geri-al')));
    await tester.pumpAndSettle();
    await _sebeple(tester, 'Yanlış iade');
    expect(a.yazilan('/finans/hareketler/iade1/iptal').single.data, {'aciklama': 'Yanlış iade'});
  });

  testWidgets('VIRMAN: kaynak -> hedef + tutar onayda; GERI AL tek bacak iptal', (tester) async {
    final a = await _kur(tester, const FinansDefteriScreen());
    await tester.tap(find.byKey(const Key('fdz-islem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-sec-virman')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-kaynak')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merkez Kasa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-hedef')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banka').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fdz-tutar')), '5000');
    await tester.tap(find.byKey(const Key('fdz-form-kaydet')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-hedef'))).data, 'Merkez Kasa → Banka');
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/virman').single.data,
        {'kaynak_kasa_id': 'k1', 'hedef_kasa_id': 'k2', 'tutar_kurus': 500000});
    await tester.tap(find.byKey(const Key('fdz-geri-al')));
    await tester.pumpAndSettle();
    await _sebeple(tester, 'Ters virman');
    expect(a.yazilan('/finans/hareketler/v1/iptal'), hasLength(1));
    expect(a.yazilan('/finans/hareketler/v2/iptal'), isEmpty, reason: 'sunucu iki bacagi birlikte ters kayitlar');
  });

  Future<void> borcluSec(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('borclular-satir-u1')));
    await tester.tap(find.byKey(const Key('borclular-satir-u2')));
    await tester.pumpAndSettle();
  }

  testWidgets('BORCLULAR: faiz affi onayli; plan ve toplu tahsilat govdeleri', (tester) async {
    final a = await _kur(tester, const BorclularScreen());
    await borcluSec(tester);
    await tester.tap(find.byKey(const Key('borclular-faiz-affi')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-hedef'))).data, contains('A-1, A-2'));
    expect(a.yazilan('/finans/borclulara/faiz-affi'), isEmpty);
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/borclulara/faiz-affi').single.data, {'unit_ids': ['u1', 'u2']});

    await borcluSec(tester);
    await tester.tap(find.byKey(const Key('borclular-odeme-plani')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fdz-taksit')), '6');
    await tester.tap(find.byKey(const Key('fdz-form-kaydet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    final plan = a.yazilan('/finans/borclulara/odeme-plani').single.data as Map;
    expect(plan['unit_ids'], ['u1', 'u2']);
    expect(plan['taksit_sayisi'], 6);
    expect(plan['ilk_vade'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    await borcluSec(tester);
    await tester.tap(find.byKey(const Key('borclular-toplu-tahsilat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fdz-kasa')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merkez Kasa').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fdz-toplu-u2')), '1500');
    await tester.tap(find.byKey(const Key('fdz-form-kaydet')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('finans-onay-tutar'))).data, contains('2.500,00'));
    await tester.tap(find.byKey(const Key('finans-onay-dugme')));
    await tester.pumpAndSettle();
    expect(a.yazilan('/finans/tahsilat/toplu').single.data, {
      'kasa_id': 'k1',
      'satirlar': [
        {'unit_id': 'u1', 'user_id': 'p1', 'tutar_kurus': 100000},
        {'unit_id': 'u2', 'tutar_kurus': 150000},
      ],
    });
  });
}
