/// (P253 Asama 2) BORCLANDIRMA — mobil yonetici.
///
/// Taklit HTTP ADAPTORUNDE (govdeyi kuran katman da olculur):
///   * liste karti + ayrinti + TERS KAYIT (§C: hedef+tutar, sebepsiz pasif,
///     govdede `aciklama`);
///   * tekil borclandirma — web `TekilModal` ile ayni govde, §C onayi;
///   * toplu tahakkuk sihirbazi — onizleme ve isleme AYNI govde, blok
///     suzgeci, dagitim toplami, geri alinamazlik onceden yazili;
///   * gecikme faizi — onizleme + onay + isle;
///   * daire borc durumu + odeme kaydi (Idempotency-Key).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/borclandirma/data/borclandirma_api.dart';
import 'package:mobile/src/features/borclandirma/domain/borclandirma_models.dart';
import 'package:mobile/src/features/borclandirma/presentation/borc_etiketleri.dart';
import 'package:mobile/src/features/borclandirma/presentation/borclandirmalar_screen.dart';
import 'package:mobile/src/features/borclandirma/presentation/daire_borc_durumu.dart';
import 'package:mobile/src/features/borclandirma/presentation/toplu_tahakkuk_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Istek {
  _Istek(this.metot, this.yol, this.govde, this.basliklar);
  final String metot;
  final String yol;
  final Object? govde;
  final Map<String, dynamic> basliklar;
}

const _tahakkuk = {
  'id': 'a-1',
  'unit_id': 'u-12',
  'donem': '2026-09',
  'tutar_kurus': 125000,
  'gelir_gider_tanim_ad': 'Eylül aidatı',
  'hedef_ad': 'Ahmet YILMAZ',
  'kalem_tipi': 'aidat',
  'iptal_edildi': false,
  'created_at': '2026-09-01T10:00:00Z',
};

class _Adaptor implements HttpClientAdapter {
  final List<_Istek> istekler = [];

  Object _yanit(String metot, String yol) => switch ((metot, yol)) {
        ('GET', '/units') => {
            'items': [
              {'id': 'u-12', 'no': 'A-12', 'blok': 'A'},
              {'id': 'u-13', 'no': 'A-13', 'blok': 'A'},
              {'id': 'u-21', 'no': 'B-1', 'blok': 'B'},
            ],
          },
        ('GET', '/gelir-gider-tanimlari') => {
            'items': [
              {'id': 't-aidat', 'ad': 'Aidat', 'tip': 'gider'},
              {'id': 't-gelir', 'ad': 'Kira geliri', 'tip': 'gelir'},
            ],
          },
        ('GET', '/dues/assessments') => {
            'items': [_tahakkuk],
            'meta': {'total': 1},
          },
        ('POST', '/dues/assessments') => {
            'created': [_tahakkuk],
            'atlanan': 0,
            'olusan': 1,
          },
        ('POST', '/dues/assessments/a-1/ters-kayit') => _tahakkuk,
        ('GET', '/units/u-12/dues') => {
            'unit_id': 'u-12',
            'no': 'A-12',
            'toplam_tahakkuk_kurus': 125000,
            'toplam_odenen_kurus': 25000,
            'bakiye_kurus': 100000,
            'assessments': [_tahakkuk],
            'payments': [
              {
                'id': 'p-1',
                'tutar_kurus': 25000,
                'odeme_zamani': '2026-09-05T10:00:00Z',
                'yontem': 'elden',
                'durum': 'basarili',
              },
            ],
          },
        ('POST', '/dues/payments') => {'id': 'p-2'},
        ('POST', '/borclandirma/toplu/onizleme') => {
            'satirlar': [
              {'unit_id': 'u-12', 'unit_no': 'A-12', 'tutar_kurus': 60000},
              {'unit_id': 'u-13', 'unit_no': 'A-13', 'tutar_kurus': 40000},
              {
                'unit_id': 'u-14',
                'unit_no': 'A-14',
                'atlama_nedeni': 'arsa_payi_girilmemis',
              },
            ],
            'islenecek': 2,
            'atlanacak': 1,
            'hedefsiz': 0,
            'toplam_kurus': 100000,
          },
        ('POST', '/borclandirma/parti/p-1/geri-al') => {
            'geri_alinan': 1,
            'atlananlar': [
              {'unit_id': 'u-1', 'unit_no': 'A-1', 'neden': 'odenmis'},
            ],
          },
        ('POST', '/borclandirma/toplu') => {
            'created': [],
            'parti_id': 'p-1',
            'olusan': 2,
            'atlanan': 1,
            'atlananlar': [
              {'unit_id': 'u-14', 'unit_no': 'A-14', 'neden': 'arsa_payi_girilmemis'},
            ],
          },
        ('GET', '/borclandirma/gecikme-faizi/onizleme') => {
            'donem': '2026-10',
            'uygulaniyor': true,
            'aylik_yuzde': 5,
            'toplam_fark_kurus': 3500,
            'items': [
              {'assessment_id': 'a-1'},
              {'assessment_id': 'a-2'},
            ],
          },
        ('POST', '/borclandirma/gecikme-faizi/isle') => {
            'donem': '2026-10',
            'yazilan': 2,
            'toplam_kurus': 3500,
            'items': [],
          },
        _ => <String, dynamic>{},
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(_Istek(o.method, o.path, o.data, o.headers));
    return ResponseBody.fromString(jsonEncode(_yanit(o.method, o.path)), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  _Istek tek(String metot, String yol) =>
      istekler.where((i) => i.metot == metot && i.yol == yol).single;
}

Future<_Adaptor> _ciz(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final adaptor = _Adaptor();
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adaptor;
  await tester.pumpWidget(ProviderScope(
    overrides: [borclandirmaApiProvider.overrideWithValue(BorclandirmaApi(dio))],
    child: l10nApp(ekran),
  ));
  await tester.pumpAndSettle();
  return adaptor;
}

Text _metin(WidgetTester tester, String anahtar) =>
    tester.widget<Text>(find.byKey(Key(anahtar)));

Future<void> _onayla(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('finans-onay-dugme')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('LISTE: daire + kisi + tutar; TERS KAYIT §C (hedef, tutar, sebep zorunlu)',
      (tester) async {
    final a = await _ciz(tester, const BorclandirmalarScreen());
    expect(find.text('A-12 · Ahmet YILMAZ'), findsOneWidget);
    expect(find.textContaining('Eylül aidatı'), findsWidgets);

    await tester.tap(find.byKey(const Key('brc-kart-a-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-ters-kayit')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'finans-onay-hedef').data, contains('A-12'));
    expect(_metin(tester, 'finans-onay-hedef').data, contains('Ahmet YILMAZ'));
    expect(_metin(tester, 'finans-onay-tutar').data, contains('1.250,00'));
    final dugme = find.byKey(const Key('finans-onay-dugme'));
    expect(tester.widget<FilledButton>(dugme).onPressed, isNull, reason: 'sebepsiz pasif');
    await tester.enterText(find.byKey(const Key('finans-onay-sebep')), 'ab');
    await tester.pump();
    expect(tester.widget<FilledButton>(dugme).onPressed, isNull, reason: '3 karakterden kisa');
    await tester.enterText(find.byKey(const Key('finans-onay-sebep')), 'Yanlış daireye yazıldı');
    await tester.pump();
    await _onayla(tester);
    expect(a.tek('POST', '/dues/assessments/a-1/ters-kayit').govde,
        {'aciklama': 'Yanlış daireye yazıldı'});
  });

  testWidgets('TEKIL: gelir turu listelenmez; onayda hedef+tutar; web ile ayni govde',
      (tester) async {
    final a = await _ciz(tester, const BorclandirmalarScreen());
    await tester.tap(find.byKey(const Key('brc-tekil-ac')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('brc-tekil-daire')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-12').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-tekil-tur')));
    await tester.pumpAndSettle();
    expect(find.text('Kira geliri'), findsNothing, reason: 'gelir borclandirilmaz');
    await tester.tap(find.text('Aidat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brc-tekil-tutar')), '750');
    await tester.tap(find.byKey(const Key('brc-tekil-kaydet')));
    await tester.pumpAndSettle();

    expect(_metin(tester, 'finans-onay-hedef').data, contains('A-12'));
    expect(_metin(tester, 'finans-onay-hedef').data, contains('Aidat'));
    expect(_metin(tester, 'finans-onay-tutar').data, contains('750,00'));
    expect(a.istekler.where((i) => i.metot == 'POST'), isEmpty, reason: 'onaysiz istek yok');
    await _onayla(tester);

    final govde = a.tek('POST', '/dues/assessments').govde! as Map;
    expect(govde['unit_id'], 'u-12');
    expect(govde['gelir_gider_tanim_id'], 't-aidat');
    expect(govde['tutar_kurus'], 75000);
    expect(govde['donem'], donemden(DateTime.now()));
    expect(govde['gecikme_uygula'], true);
  });

  testWidgets('TOPLU SIHIRBAZ: blok + esit dagitim; onizleme ve isleme AYNI govde',
      (tester) async {
    final a = await _ciz(tester, const TopluTahakkukScreen());
    // 1/5 Ne
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brc-toplu-hata')), findsOneWidget, reason: 'tur zorunlu');
    await tester.tap(find.byKey(const Key('brc-toplu-tur')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aidat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    // 2/5 Ne kadar
    await tester.tap(find.byKey(const Key('brc-toplu-dagitim-esit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brc-toplu-hata')), findsOneWidget, reason: 'dagitimda toplam zorunlu');
    await tester.enterText(find.byKey(const Key('brc-toplu-tutar')), '1000');
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    // 3/5 Kime
    await tester.tap(find.byKey(const Key('brc-toplu-kapsam-blok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-toplu-blok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    // 4/5 Onizleme
    final onizleme = a.tek('POST', '/borclandirma/toplu/onizleme').govde! as Map;
    expect(onizleme['suzgec'], {'blok': 'A'});
    expect(onizleme['dagitim'], 'esit');
    expect(onizleme['toplam_tutar_kurus'], 100000);
    expect(onizleme.containsKey('tutar_kurus'), isFalse, reason: 'ayni alan iki anlam tasimaz');
    expect(_metin(tester, 'brc-toplu-islenecek').data, contains('2'));
    expect(_metin(tester, 'brc-toplu-toplam').data, contains('1.000,00'));
    expect(find.textContaining('Arsa payı girilmemiş'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brc-toplu-ileri')));
    await tester.pumpAndSettle();
    // 5/5 Onay — geri alinamazlik ONCEDEN yazili
    expect(find.byKey(const Key('brc-toplu-geri-alinamaz')), findsOneWidget);
    await tester.tap(find.byKey(const Key('brc-toplu-isle')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'finans-onay-hedef').data, startsWith('2 daire · Aidat'));
    expect(_metin(tester, 'finans-onay-tutar').data, contains('1.000,00'));
    await _onayla(tester);
    expect(a.tek('POST', '/borclandirma/toplu').govde, onizleme);
    expect(_metin(tester, 'brc-toplu-sonuc').data, '2 daireye borç yazıldı');
    expect(find.textContaining('A-14'), findsOneWidget);

    // (P253 §C-4) GERI AL: parti tek istekte; sebep ZORUNLU, govdede.
    await tester.tap(find.byKey(const Key('brc-parti-geri-al')));
    await tester.pumpAndSettle();
    final onay = find.byKey(const Key('finans-onay-dugme'));
    expect(tester.widget<FilledButton>(onay).onPressed, isNull, reason: 'sebepsiz pasif');
    await tester.enterText(find.byKey(const Key('finans-onay-sebep')), 'Yanlış dönem');
    await tester.pumpAndSettle();
    await _onayla(tester);
    expect(a.tek('POST', '/borclandirma/parti/p-1/geri-al').govde, {'aciklama': 'Yanlış dönem'});
    expect(_metin(tester, 'brc-parti-geri-alindi').data, contains('1'));
    expect(find.textContaining('ödeme almış'), findsOneWidget);
  });

  testWidgets('GECIKME FAIZI: onizleme ozeti, onay, isle', (tester) async {
    final a = await _ciz(tester, const BorclandirmalarScreen());
    await tester.tap(find.byKey(const Key('brc-faiz-ac')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'brc-faiz-ozet').data, contains('35,00'));
    await tester.tap(find.byKey(const Key('brc-faiz-isle')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'finans-onay-hedef').data, contains('2 borç'));
    expect(a.istekler.where((i) => i.yol == '/borclandirma/gecikme-faizi/isle'), isEmpty);
    await _onayla(tester);
    a.tek('POST', '/borclandirma/gecikme-faizi/isle');
  });

  testWidgets('DAIRE BORC DURUMU + ODEME: ozet, onay, Idempotency-Key, govde', (tester) async {
    // Gercekte merkez pencere icinde (Material); testte Scaffold saglar.
    final a = await _ciz(tester, const Scaffold(body: DaireBorcDurumu(unitId: 'u-12')));
    expect(find.textContaining('1.000,00'), findsWidgets, reason: 'bakiye');
    await tester.tap(find.byKey(const Key('brc-daire-odeme')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brc-odeme-tutar')), '250');
    await tester.enterText(find.byKey(const Key('brc-odeme-makbuz')), 'MK-9');
    await tester.tap(find.byKey(const Key('brc-odeme-kaydet')));
    await tester.pumpAndSettle();
    expect(_metin(tester, 'finans-onay-hedef').data, contains('A-12'));
    expect(_metin(tester, 'finans-onay-tutar').data, contains('250,00'));
    await _onayla(tester);
    final odeme = a.tek('POST', '/dues/payments');
    expect(odeme.govde, {
      'unit_id': 'u-12',
      'tutar_kurus': 25000,
      'yontem': 'elden',
      'makbuz_no': 'MK-9',
      'assessment_id': null,
      'donem': null,
    });
    expect(odeme.basliklar['Idempotency-Key'], isNotEmpty);
  });

  test('GOVDE: daire basina modunda tutar_kurus; secili daireler unit_ids', () {
    const g = TopluBorcGovdesi(
      donem: '2026-10',
      tanimId: 't',
      dagitim: 'daire_basina',
      kalemTipi: 'aidat',
      kapsam: TopluKapsam.secili,
      tutarKurus: 5000,
      unitIds: ['u-1', 'u-2'],
    );
    final j = g.toJson();
    expect(j['tutar_kurus'], 5000);
    expect(j.containsKey('toplam_tutar_kurus'), isFalse);
    expect(j['suzgec'], {'unit_ids': ['u-1', 'u-2']});
  });

  testWidgets('DAR EKRAN 320 dp: liste ve sihirbaz TASMAZ', (tester) async {
    for (final ekran in const <Widget>[BorclandirmalarScreen(), TopluTahakkukScreen()]) {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _Adaptor();
      await tester.pumpWidget(ProviderScope(
        overrides: [borclandirmaApiProvider.overrideWithValue(BorclandirmaApi(dio))],
        child: l10nApp(ekran),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$ekran');
    }
  });
}
