/// (P241 §2) VARDIYA MOBIL — taslak, izin, yayin, mola/rol/lokasyon.
///
/// ===========================================================================
/// NE OLCULUYOR
/// ===========================================================================
/// Kurallar SUNUCUDA kilitli (`test_p241_vardiya.py`). Burada olculen:
/// mobil yuzeyin o gercekleri DOGRU gosterdigi ve DOGRU govdeyi
/// gonderdigi. Taklit HTTP adapter'inda (P200 dersi): govdeyi kuran
/// katman da testin icinden geciyor.
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
  final istekler = <({
    String yol,
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
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final bugun = DateTime.now();
    String g(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final pazartesi = DateTime(bugun.year, bugun.month, bugun.day)
        .subtract(Duration(days: bugun.weekday - 1));
    final govde = switch (options.path) {
      '/vardiya-plani/cizelge' => {
          'baslangic': g(pazartesi),
          'bitis': g(pazartesi.add(const Duration(days: 6))),
          'personel': [
            {
              'user_id': 'u-1',
              'ad': 'Ali Guvenlik',
              'rol': 'security',
              'toplam_saat': 11.0,
              'hedef_saat': 45.0,
              'izinler': <Map<String, dynamic>>[],
              'bloklar': [
                {
                  'plan_id': 'p-1',
                  'tarih': g(pazartesi),
                  'baslar': '${g(pazartesi)}T08:00:00',
                  'biter': '${g(pazartesi)}T20:00:00',
                  'shift_ad': 'Gunduz',
                  'not_metni': null,
                  'gece_asiyor': false,
                  'vardiya_rolu': 'temizlik',
                  'blok_ad': null,
                  'alan': 'Otopark',
                  'calisma_saat': 11.0,
                  'mola_dakika': 60,
                  // TASLAK: personel gormez, yonetim ISARETLI gorur.
                  'yayinlandi_at': null,
                  'yayin_bekliyor': false,
                },
              ],
            },
            {
              'user_id': 'u-2',
              'ad': 'Veli Izinli',
              'rol': 'security',
              'toplam_saat': 0.0,
              'hedef_saat': 45.0,
              'bloklar': <Map<String, dynamic>>[],
              'izinler': [
                {
                  'izin_id': 'i-1',
                  'tur': 'yillik',
                  'baslangic': g(pazartesi),
                  'bitis': g(pazartesi),
                  'tum_gun': true,
                },
              ],
            },
          ],
        },
      '/vardiya-plani/simdi' => {
          'zaman': '${g(pazartesi)}T10:00:00',
          'gorevdeki_vardiya': null,
          'gorevdekiler': <Map<String, dynamic>>[],
          'sonraki_vardiya': null,
          'sonrakiler': <Map<String, dynamic>>[],
        },
      '/vardiya-plani/yayin-ozeti' => {
          'bekleyen': 3,
          'taslak': 2,
          'degisen': 1,
        },
      '/vardiya-plani/yayinla' => {'yayinlanan': 3, 'bildirilen_kisi': 2},
      '/vardiya-plani/mola-onerisi' => {
          'sure_saat': 12.0,
          'onerilen_dakika': 60,
        },
      '/vardiya-izin' => {'id': 'i-9', 'durum': 'onaylandi'},
      '/users' => {
          'items': [
            {'id': 'u-1', 'ad': 'Ali Guvenlik', 'role': 'security', 'is_active': true},
          ],
        },
      '/vardiya-plani/toplu' => {
          'uygulandi': true,
          'eklenen': 1,
          'cakisan': 0,
          'gunler': <Map<String, dynamic>>[],
          'uyarilar': <String>[],
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

Future<_Tel> _sur(WidgetTester tester, {String rol = 'yonetici'}) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final depo = BellekDepo({
    // `sub` SART: izin formu kendi kimligine dusuyor ve `sub`siz bir
    // jeton gercekte de olmaz (sunucu her zaman yaziyor).
    'auth.access_token':
        sahteJwt({'role': rol, 'tenant_id': 't-1', 'sub': 'u-1'}),
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
  testWidgets('TASLAK vardiya YAZIYLA isaretlenir', (tester) async {
    // Renk tek basina anlam tasimamali: sahada gunes altinda renk
    // farki zaten kayboluyor.
    await _sur(tester);
    expect(find.byKey(const Key('vardiya-taslak-p-1')), findsOneWidget);
  });

  testWidgets('ROL ETIKETI, LOKASYON ve CALISMA SAATI satirda gorunur',
      (tester) async {
    await _sur(tester);
    expect(find.textContaining('temizlik'), findsWidgets);
    expect(find.textContaining('Otopark'), findsWidgets);
    // 12 saatlik vardiya, 1 saat mola -> 11 saat. SUNUCUDAN geliyor.
    expect(find.textContaining('11'), findsWidgets);
  });

  testWidgets('IZINLI KISI AYRI SATIRDA — vardiya satiri DEGIL',
      (tester) async {
    final bugun = DateTime.now();
    final pazartesi = DateTime(bugun.year, bugun.month, bugun.day)
        .subtract(Duration(days: bugun.weekday - 1));
    final g =
        '${pazartesi.year}-${pazartesi.month.toString().padLeft(2, '0')}-${pazartesi.day.toString().padLeft(2, '0')}';
    await _sur(tester);
    expect(find.byKey(Key('vardiya-izinli-u-2-$g')), findsOneWidget);
  });

  testWidgets('YAYINLA dugmesinde SAYI var ve ucu cagirir', (tester) async {
    final tel = await _sur(tester);
    final dugme = find.byKey(const Key('vardiya-yayinla'));
    expect(dugme, findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    await tester.tap(dugme);
    await tester.pumpAndSettle();
    expect(
      tel.istekler.any(
        (i) => i.yol == '/vardiya-plani/yayinla' && i.metot == 'POST',
      ),
      isTrue,
    );
  });

  testWidgets('SAHA ROLU yayin araclarini GORMEZ', (tester) async {
    // Sunucu da 403 doner; dugmeyi gostermek reddedilecek bir eylemi
    // davet etmek olurdu.
    await _sur(tester, rol: 'security');
    expect(find.byKey(const Key('vardiya-yayinla')), findsNothing);
    expect(find.byKey(const Key('vardiya-izin-ac')), findsNothing);
  });

  testWidgets('IZIN FORMU acilir ve IZIN ucuna DOGRU govde gider',
      (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byKey(const Key('vardiya-izin-ac')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('izin-tur')), findsOneWidget);
    // Kisi secilmeden kaydet: `user_id` BOS gitmez — kendi kimligine
    // duser ve bu bilincli (form kendi adina da talep acabilir).
    await tester.tap(find.byKey(const Key('izin-kaydet')));
    await tester.pumpAndSettle();
    final istek = tel.istekler.where((i) => i.yol == '/vardiya-izin');
    expect(istek.isNotEmpty, isTrue);
    expect(istek.first.govde['tur'], 'yillik');
    expect(istek.first.govde['tum_gun'], isTrue);
  });

  testWidgets('MOLA / ROL / LOKASYON govdede gider', (tester) async {
    // GENIS YUZEY: ekleme dialogu uzun ve varsayilan 800x600 test
    // yuzeyinde kisi secici gorunur alanin disinda kaliyor. Olculen sey
    // YERLESIM DEGIL govde; yuzeyi buyutmek olcumu bozmuyor.
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tel = await _sur(tester);
    await tester.tap(find.byKey(const Key('vardiya-yeni')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('vardiya-ekle-mola')), '45');
    await tester.enterText(find.byKey(const Key('vardiya-ekle-rol')), 'guvenlik');
    await tester.enterText(
        find.byKey(const Key('vardiya-ekle-lokasyon')), 'A Blok');
    // Kisi secimi — once GORUNUR YAP: dialog icerigi kayabiliyor ve
    // ekran disindaki bir widget'a dokunmak vurus testinde duser.
    await tester.ensureVisible(find.byKey(const Key('vardiya-ekle-kisi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vardiya-ekle-kisi')));
    await tester.pumpAndSettle();
    // ACILAN MENUDEKI ogeyi sec: `DropdownMenuItem` gorunumu
    // aranir — arka plandaki liste satirinda da ayni ad geciyor.
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vardiya-ekle-gonder')));
    await tester.pumpAndSettle();

    final istek =
        tel.istekler.where((i) => i.yol == '/vardiya-plani/toplu').toList();
    expect(istek.isNotEmpty, isTrue, reason: 'toplu ucu cagrilmadi');
    final govde = istek.last.govde;
    expect(govde['vardiya_rolu'], 'guvenlik');
    expect(govde['alan'], 'A Blok');
    expect((govde['molalar'] as List).first['dakika'], 45);
  });
}
