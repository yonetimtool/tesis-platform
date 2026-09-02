/// (P205 §2.4) VARDIYA PLANI — MOBIL: gun gun liste + hizli ekleme.
///
/// ===========================================================================
/// BU DOSYA P203'UN MOBIL TESTININ YERINI ALDI
/// ===========================================================================
/// Ekran artik `/vardiya-plani/cizelge` okuyor: izgara ucu yalniz
/// SABLONA bagli slotlari donuyordu ve web'den serbest saatle eklenen
/// bir vardiya SAHADA HIC GORUNMEZDI. Olculen sey: hangi uca gidildi,
/// ekranda ne cizildi ve toplu eklemede CAKISMA nasil ele alindi.
///
/// Taklit HTTP adapter'inda (P200 dersi): govdeyi kuran katman da
/// testin icinden geciyor.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_plani_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  _Tel({this.topluYaniti});

  /// `/vardiya-plani/toplu` yanitini degistirerek cakisma dali surulur.
  final Map<String, dynamic>? topluYaniti;

  final istekler = <({
    String yol,
    Map<String, dynamic> sorgu,
    String metot,
    Map<String, dynamic> govde,
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
      sorgu: Map<String, dynamic>.from(options.queryParameters),
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    const gunduz = {
      'shift_id': 's-1',
      'shift_ad': 'Gunduz',
      'baslangic_saat': '08:00:00',
      'bitis_saat': '16:00:00',
      'kisiler': [
        {'plan_id': 'p-1', 'user_id': 'u-1', 'ad': 'Ali Guvenlik', 'rol': 'security'},
      ],
      'bos': false,
    };
    const geceBos = {
      'shift_id': 's-2',
      'shift_ad': 'Gece',
      'baslangic_saat': '20:00:00',
      'bitis_saat': '08:00:00',
      'kisiler': <Map<String, dynamic>>[],
      'bos': true,
    };
    final govde = switch (options.path) {
      '/vardiya-plani/cizelge' => {
          'baslangic': '2026-09-02',
          'bitis': '2026-09-08',
          'personel': [
            {
              'user_id': 'u-1',
              'ad': 'Ali Guvenlik',
              'rol': 'security',
              'bloklar': [
                {
                  'plan_id': 'p-1',
                  'tarih': '2026-09-02',
                  'baslar': '2026-09-02T08:00:00',
                  'biter': '2026-09-02T16:00:00',
                  'shift_ad': 'Gunduz',
                  'not_metni': null,
                  'gece_asiyor': false,
                },
                {
                  // SERBEST (sablonsuz) + GECE ASIRI blok: eski izgara
                  // ucunda GORUNMEYEN tam da buydu.
                  'plan_id': 'p-2',
                  'tarih': '2026-09-03',
                  'baslar': '2026-09-03T22:00:00',
                  'biter': '2026-09-04T05:00:00',
                  'shift_ad': null,
                  'not_metni': null,
                  'gece_asiyor': true,
                },
              ],
            },
            {'user_id': 'u-2', 'ad': 'Veli Bos', 'rol': 'security', 'bloklar': []},
          ],
        },
      '/vardiya-plani/simdi' => {
          'zaman': '2026-09-02T10:00:00',
          'gorevdeki_vardiya': gunduz,
          'gorevdekiler': gunduz['kisiler'],
          'sonraki_vardiya': geceBos,
          'sonrakiler': [
            {'plan_id': 'p-9', 'user_id': 'u-9', 'ad': 'Veli Gece', 'rol': 'security'},
          ],
        },
      '/users' => {
          'items': [
            {'id': 'u-1', 'ad': 'Ali Guvenlik', 'role': 'security', 'is_active': true},
            {'id': 'u-2', 'ad': 'Veli Bos', 'role': 'guvenlik_amiri', 'is_active': true},
            {'id': 'u-3', 'ad': 'Sakin Kisi', 'role': 'resident', 'is_active': true},
          ],
        },
      '/vardiya-plani/toplu' => topluYaniti ??
          {'uygulandi': true, 'eklenen': 3, 'cakisan': 0, 'gunler': [], 'uyarilar': []},
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
  WidgetTester tester, {
  String rol = 'security',
  Map<String, dynamic>? toplu,
}) async {
  final tel = _Tel(topluYaniti: toplu);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': rol, 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const VardiyaPlaniScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('CIZELGE ucundan okur ve GUN GUN cizer', (tester) async {
    // 24 saatlik yatay eksen 360 dp'ye sigmaz (karar K2.5): sahadaki
    // soru "bugun kim var" ve LISTE bunu tek bakista yanitlar.
    final tel = await _sur(tester);
    expect(
      tel.istekler.any((i) => i.yol == '/vardiya-plani/cizelge'),
      isTrue,
      reason: 'cizelge ucu cagrilmadi',
    );
    // ESKI IZGARA UCU ARTIK CAGRILMIYOR.
    expect(tel.istekler.any((i) => i.yol == '/vardiya-plani'), isFalse);

    expect(find.byKey(const Key('vardiya-gun-2026-09-02')), findsOneWidget);
    expect(find.byKey(const Key('vardiya-gun-2026-09-03')), findsOneWidget);
    expect(find.byKey(const Key('vardiya-blok-p-1')), findsOneWidget);
    // SERBEST (sablonsuz) vardiya da GORUNUR — eski ucta gorunmuyordu.
    expect(find.byKey(const Key('vardiya-blok-p-2')), findsOneWidget);
    expect(find.text('22:00–05:00'), findsOneWidget);
  });

  testWidgets('ANLIK DURUM: su an gorevde + siradaki', (tester) async {
    await _sur(tester);
    final kart = find.byKey(const Key('vardiya-simdi'));
    expect(kart, findsOneWidget);
    expect(find.descendant(of: kart, matching: find.textContaining('Ali Guvenlik')),
        findsOneWidget);
    expect(find.descendant(of: kart, matching: find.textContaining('Veli Gece')),
        findsOneWidget);
  });

  testWidgets('SAHA ROLU yazma araclarini GORMEZ', (tester) async {
    // Yazma sunucuda admin+yonetici ile sinirli; dugmeyi gostermek
    // gorevliye 403 yedirmek olurdu.
    await _sur(tester, rol: 'security');
    expect(find.byKey(const Key('vardiya-cikar-p-1')), findsNothing);
    expect(find.byKey(const Key('vardiya-yeni')), findsNothing);
  });

  testWidgets('YONETICI cikarabilir ve SEBEP sorulur', (tester) async {
    // Gun ici degisiklik denetime yaziliyor; "neden" bos kalirsa kayit
    // sonradan hicbir soruyu yanitlayamaz.
    final tel = await _sur(tester, rol: 'yonetici');
    await tester.tap(find.byKey(const Key('vardiya-cikar-p-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vardiya-cikar-sebep')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('vardiya-cikar-sebep')), 'grip');
    await tester.tap(find.byKey(const Key('vardiya-cikar-onayla')));
    await tester.pumpAndSettle();

    final silme = tel.istekler.where((i) => i.metot == 'DELETE');
    expect(silme, hasLength(1));
    expect(silme.single.yol, '/vardiya-plani/p-1');
    // SEBEP SORGUDA tasinir: DELETE govdesi bazi yiginlarda sessizce
    // duser ve denetim kaydi "neden" sorusunu yanitlayamazdi.
    expect(silme.single.sorgu['not_metni'], 'grip');
  });

  // ==================== HIZLI EKLEME (§2.4) ============================= #

  testWidgets('HIZLI EKLEME govdesi: saatler + ATLAMA BAYRAGI KAPALI',
      (tester) async {
    final tel = await _sur(tester, rol: 'yonetici');
    await tester.tap(find.byKey(const Key('vardiya-yeni')));
    await tester.pumpAndSettle();

    // SAKIN listede YOK: vardiya personele yazilir.
    await tester.tap(find.byKey(const Key('vardiya-ekle-kisi')));
    await tester.pumpAndSettle();
    expect(find.text('Sakin Kisi'), findsNothing);
    // Guvenlik amiri LISTEDE: `getFieldStaff` onu disarida birakiyordu
    // ve mobilde ona vardiya yazmak imkansiz olurdu.
    await tester.tap(find.text('Veli Bos').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vardiya-ekle-gonder')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/vardiya-plani/toplu');
    expect(post.govde['user_id'], 'u-2');
    expect(post.govde['baslangic_saat'], '08:00');
    expect(post.govde['bitis_saat'], '16:00');
    // ILK ISTEKTE ATLAMA KAPALI: cakisan gunler SORULMADAN atlanamaz.
    expect(post.govde['cakisanlari_atla'], isFalse);
  });

  testWidgets('CAKISMA: gunler GOSTERILIR, karar KULLANICININ',
      (tester) async {
    final tel = await _sur(tester, rol: 'yonetici', toplu: {
      'uygulandi': false,
      'eklenen': 0,
      'cakisan': 2,
      'gunler': [
        {'tarih': '2026-09-03', 'durum': 'cakisma', 'plan_id': null},
        {'tarih': '2026-09-04', 'durum': 'eklenebilir', 'plan_id': null},
        {'tarih': '2026-09-05', 'durum': 'cakisma', 'plan_id': null},
      ],
      'uyarilar': <String>[],
    });
    await tester.tap(find.byKey(const Key('vardiya-yeni')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vardiya-ekle-kisi')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Guvenlik').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vardiya-ekle-gonder')));
    await tester.pumpAndSettle();

    // HANGI GUNLER oldugu YAZILIR — "bir yerde cakisma var" demek,
    // kullaniciyi tek tek aramaya gondermek olurdu.
    expect(find.byKey(const Key('vardiya-cakisma-uyarisi')), findsOneWidget);
    // (Gun listesi hem uyari satirinda hem tarih alaninda gecebiliyor;
    // olculen sey VARLIGI.)
    expect(find.textContaining('2026-09-03'), findsWidgets);

    await tester.tap(find.byKey(const Key('vardiya-cakisan-haric')));
    await tester.pumpAndSettle();

    final istekler =
        tel.istekler.where((i) => i.yol == '/vardiya-plani/toplu').toList();
    expect(istekler, hasLength(2));
    // IKINCI istek ATLAMA ACIK gider — ve bu KULLANICININ kararidir.
    expect(istekler.last.govde['cakisanlari_atla'], isTrue);
  });

  testWidgets('ARALIK ve GECE ASIRI davranisi ONCEDEN yazar', (tester) async {
    await _sur(tester, rol: 'yonetici');
    await tester.tap(find.byKey(const Key('vardiya-yeni')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vardiya-ekle-bilgi')), findsOneWidget);
  });
}
