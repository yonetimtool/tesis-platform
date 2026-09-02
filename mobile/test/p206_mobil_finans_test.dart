/// (P206 §4.1/4.3/4.4) MOBIL FINANS — tahsilat, gider, borclular.
///
/// ===========================================================================
/// ONCE OLCUM: BU UCU DE MOBILDE YOKTU
/// ===========================================================================
/// P204'te "web'de var, mobilde yok" diye isaretlenmisti; P206 §4'te
/// dogrulandi — mobil uygulamada `/finans/tahsilat`, `/finans/hareketler`
/// ve `/finans/yaslandirma` uclarina giden HICBIR cagri yoktu.
///
/// Taklit HTTP adapter'inda (P200 dersi): govdeyi kuran katman da testin
/// icinden geciyor. Olculen sey: hangi uca, hangi govdeyle, hangi
/// BASLIKLARLA gidildi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/finans/presentation/borclular_screen.dart';
import 'package:mobile/src/features/finans/presentation/gider_screen.dart';
import 'package:mobile/src/features/finans/presentation/tahsilat_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  _Tel({this.borclular});

  final Map<String, dynamic>? borclular;

  final istekler = <({
    String yol,
    String metot,
    Map<String, dynamic> govde,
    Map<String, dynamic> basliklar,
  })>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
      basliklar: Map<String, dynamic>.from(options.headers),
    ));
    final govde = switch (options.path) {
      '/finans/yaslandirma' => borclular ??
          {
            'kovalar': [
              {
                'kova': '0-30',
                'daire': 2,
                'kalan_kurus': 175000,
                'daireler': [
                  {
                    'unit_id': 'u-1',
                    'unit_no': 'A-3',
                    'kalan_kurus': 125000,
                    'en_eski_gun': 12,
                    'borclu_ad': 'Ahmet Borclu',
                    'borclu_user_id': 'k-1',
                  },
                  {
                    'unit_id': 'u-2',
                    'unit_no': 'A-4',
                    'kalan_kurus': 50000,
                    'en_eski_gun': 5,
                    'borclu_ad': 'Ayse Borclu',
                    'borclu_user_id': 'k-2',
                  },
                ],
              },
            ],
            'toplam_kalan_kurus': 175000,
            'toplam_daire': 2,
          },
      '/kasalar' => {
          'items': [
            {'id': 'kasa-1', 'ad': 'Merkez Kasa', 'banka_mi': false},
          ],
          'meta': {'total': 1},
        },
      '/gelir-gider-tanimlari' => {
          'items': [
            {'id': 'tur-1', 'ad': 'Temizlik'},
          ],
          'meta': {'total': 1},
        },
      '/finans/tahsilat-gostergesi' => {
          'donem': '2026-09',
          'tahakkuk_kurus': 100000,
          'tahsilat_kurus': 60000,
          'oran_yuzde': 60,
        },
      '/finans/hareketler' => {
          'meta': {'total': 1},
          'items': [
            {'id': 'h-1', 'tip': 'gider', 'tutar_kurus': 5000},
          ],
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(
  WidgetTester tester,
  Widget ekran, {
  Map<String, dynamic>? borclular,
}) async {
  final tel = _Tel(borclular: borclular);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': 'yonetici', 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  // =========================== 4.1 TAHSILAT ============================== #

  testWidgets('TAHSILAT: borclular tutariyla listelenir', (tester) async {
    final tel = await _sur(tester, const TahsilatScreen());
    expect(tel.istekler.any((i) => i.yol == '/finans/yaslandirma'), isTrue);
    expect(find.byKey(const Key('tahsilat-borclu-u-1')), findsOneWidget);
    expect(find.textContaining('Ahmet Borclu'), findsOneWidget);
    expect(find.textContaining('1.250,00'), findsOneWidget);
  });

  testWidgets('TAHSILAT: borclu secilince tutar KALAN BORCLA dolar',
      (tester) async {
    // Sahada en sik yapilan islem borcun TAMAMINI almak; her seferinde
    // rakam yazdirmak, kapida bekleyen kisiyle konusurken yapilacak is
    // degil.
    await _sur(tester, const TahsilatScreen());
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    final alan = tester.widget<TextField>(find.byKey(const Key('tahsilat-tutar')));
    expect(alan.controller!.text, '1.250,00');
  });

  testWidgets('TAHSILAT: govde + IDEMPOTENCY BASLIGI gider', (tester) async {
    final tel = await _sur(tester, const TahsilatScreen());
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tahsilat-kaydet')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/tahsilat');
    expect(post.govde['user_id'], 'k-1');
    expect(post.govde['unit_id'], 'u-1');
    expect(post.govde['tutar_kurus'], 125000);
    expect(post.govde['yontem'], 'elden');
    // (P192 §6.2) CIFT TIKLAMA KORUMASI MOBILDE DE: sahada baglanti
    // kopar, kullanici yeniden basar, kasada IKI hareket olusurdu.
    expect(post.basliklar['Idempotency-Key'], isNotNull);
  });

  testWidgets('TAHSILAT: TEK KASA varsa SORULMAZ', (tester) async {
    // Olmayan bir karari sormak, her tahsilata bir dokunus eklerdi.
    await _sur(tester, const TahsilatScreen());
    expect(find.byKey(const Key('tahsilat-kasa')), findsNothing);
  });

  testWidgets('TAHSILAT: BORCLU YOKSA ekran SOYLER', (tester) async {
    await _sur(tester, const TahsilatScreen(),
        borclular: {'kovalar': [], 'toplam_kalan_kurus': 0, 'toplam_daire': 0});
    expect(find.byKey(const Key('tahsilat-borclu-yok')), findsOneWidget);
  });

  // ============================ 4.3 GIDER ================================ #

  testWidgets('GIDER: govde ODENDI durumuyla gider', (tester) async {
    final tel = await _sur(tester, const GiderScreen());
    await tester.enterText(find.byKey(const Key('gider-tutar')), '50,00');
    await tester.tap(find.byKey(const Key('gider-kaydet')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/hareketler');
    final satir = (post.govde['satirlar'] as List).first as Map;
    expect(satir['tip'], 'gider');
    expect(satir['tutar_kurus'], 5000);
    expect(satir['durum'], 'odendi');
    expect(post.basliklar['Idempotency-Key'], isNotNull);
  });

  testWidgets('GIDER: ONAYA GONDER secilince durum ONAY_BEKLIYOR',
      (tester) async {
    // (P192) Onay bekleyen gider bakiyeyi DUSURMEZ ve ekran bunu YAZAR;
    // sessiz bir varsayilan, yoneticinin bakiyeyi yanlis okumasina yol
    // acardi.
    final tel = await _sur(tester, const GiderScreen());
    await tester.enterText(find.byKey(const Key('gider-tutar')), '50,00');
    await tester.tap(find.byKey(const Key('gider-onay-bekliyor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gider-kaydet')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/hareketler');
    expect(((post.govde['satirlar'] as List).first as Map)['durum'],
        'onay_bekliyor');
  });

  testWidgets('GIDER: TUTARSIZ kayit ISTEK ATMAZ', (tester) async {
    final tel = await _sur(tester, const GiderScreen());
    await tester.tap(find.byKey(const Key('gider-kaydet')));
    await tester.pumpAndSettle();
    expect(tel.istekler.any((i) => i.yol == '/finans/hareketler'), isFalse);
    expect(find.byKey(const Key('gider-hata')), findsOneWidget);
  });

  // ========================== 4.4 BORCLULAR ============================== #

  testWidgets('BORCLULAR: kovalar + liste + TEK KAYNAK tahsilat orani',
      (tester) async {
    final tel = await _sur(tester, const BorclularScreen());
    expect(find.byKey(const Key('borclular-kova-0-30')), findsOneWidget);
    expect(find.byKey(const Key('borclular-satir-u-1')), findsOneWidget);
    // ORAN AYRICA HESAPLANMAZ: `/finans/tahsilat-gostergesi` (P192 §5.2).
    expect(
      tel.istekler.any((i) => i.yol == '/finans/tahsilat-gostergesi'),
      isTrue,
    );
    expect(find.textContaining('60'), findsWidgets);
  });

  testWidgets('BORCLULAR: secim yapilinca TOPLU HATIRLATMA cikar ve gider',
      (tester) async {
    final tel = await _sur(tester, const BorclularScreen());
    // Bos secimle basilabilen bir dugme, hicbir sey yapmayip kullaniciyi
    // "gitti mi" diye birakirdi.
    expect(find.byKey(const Key('borclular-hatirlat')), findsNothing);

    await tester.tap(find.byKey(const Key('borclular-satir-u-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('borclular-hatirlat')), findsOneWidget);

    await tester.tap(find.byKey(const Key('borclular-hatirlat')));
    await tester.pumpAndSettle();
    final post =
        tel.istekler.firstWhere((i) => i.yol == '/finans/borclulara/hatirlat');
    expect((post.govde['unit_ids'] as List), ['u-1']);
  });
}
