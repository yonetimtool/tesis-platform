/// (P202) ZORUNLU / ONERILEN GUNCELLEME — akis ve KRITIK KURALLAR.
///
/// ===========================================================================
/// TAKLIT EN ALTTA: HTTP ADAPTERI
/// ===========================================================================
/// Ekran -> denetleyici -> api -> **tel uzerindeki govde** zincirinin
/// tamami gercektir (P200'de ogrenilen ders: repository duzeyinde taklit,
/// govdeyi kuran katmani olcusuz birakir).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart'
    show secureStorageProvider;
import 'package:mobile/src/features/surum/data/surum_erteleme.dart';
import 'package:mobile/src/features/surum/presentation/surum_denetleyici.dart';
import 'package:mobile/src/features/surum/presentation/surum_kapisi.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

/// Istegi KAYDEDEN, yapilandirilabilir yanit doner adapter.
class _TelAdapteri implements HttpClientAdapter {
  _TelAdapteri({this.yanit, this.hataVer = false});

  final Map<String, dynamic>? yanit;

  /// AG HATASI taklidi — "sunucuya ulasilamiyor".
  final bool hataVer;

  final istekler = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add(ham is Map<String, dynamic> ? Map.of(ham) : {});
    if (hataVer) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sunucuya ulasilamiyor',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(yanit ?? {'durum': 'guncel'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _MAGAZA = 'https://play.google.com/store/apps/details?id=com.app.yonetiyor';

/// Alttaki "gercek uygulama" — cizildiyse kullanici uygulamayi
/// KULLANABILIYOR demektir.
const _icerik = Scaffold(body: Center(child: Text('UYGULAMA ICERIGI')));

Future<({ProviderContainer kap, _TelAdapteri tel, BellekDepo depo})> _sur(
  WidgetTester tester, {
  Map<String, dynamic>? yanit,
  bool hataVer = false,
  BellekDepo? depo,
}) async {
  final tel = _TelAdapteri(yanit: yanit, hataVer: hataVer);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final d = depo ?? BellekDepo();
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(d),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(
        SurumGozcusu(child: const SurumKapisi(child: _icerik)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (kap: kap, tel: tel, depo: d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Paket surumu: gercek cihazda bundle'dan okunur.
    PackageInfo.setMockInitialValues(
      appName: 'Yonetiyor',
      packageName: 'com.app.yonetiyor',
      version: '1.0.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  // ===================== 1) ZORUNLU EKRAN CIKAR ========================= //

  testWidgets('ESKI SURUM bildiren istemci ZORUNLU ekrani gorur',
      (tester) async {
    final s = await _sur(tester, yanit: {
      'durum': 'zorunlu',
      'mesaj': 'Guvenlik guncellemesi',
      'magaza_url': _MAGAZA,
    });

    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsOneWidget);
    expect(find.text('Guvenlik guncellemesi'), findsOneWidget);
    // TEK dugme: "Guncelle". "Sonra" YOK.
    expect(find.byKey(const Key('surum-guncelle')), findsOneWidget);
    expect(find.byKey(const Key('surum-sonra')), findsNothing);
    // UYGULAMA KULLANILAMAZ: alttaki agac HIC cizilmedi.
    expect(find.text('UYGULAMA ICERIGI'), findsNothing);

    // Istemci KENDI surumunu ve platformunu BILDIRDI.
    expect(s.tel.istekler.single['surum'], '1.0.0');
    expect(s.tel.istekler.single['platform'], isNotNull);
  });

  // ===================== 2) GUNCEL SURUMDE CIKMAZ ======================= //

  testWidgets('GUNCEL surumde hicbir sey gosterilmez', (tester) async {
    await _sur(tester, yanit: {'durum': 'guncel'});
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsNothing);
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsNothing);
    expect(find.text('UYGULAMA ICERIGI'), findsOneWidget);
  });

  // ============ 3) SUNUCUYA ULASILAMIYOR -> UYGULAMA ACILIR ============= //

  testWidgets('SUNUCUYA ULASILAMAZKEN uygulama CALISMAYA DEVAM EDER',
      (tester) async {
    // Ag hatasi yuzunden kimse kilitlenmemeli: aksi hâlde bizim
    // kesintimiz, kullanicinin telefonunda "uygulama acilmiyor" olurdu.
    final s = await _sur(tester, hataVer: true);
    expect(find.text('UYGULAMA ICERIGI'), findsOneWidget);
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsNothing);
    expect(s.tel.istekler, hasLength(1), reason: 'istek denendi ama yutuldu');
  });

  testWidgets('BILINMEYEN DURUM degeri kullaniciyi KILITLEMEZ',
      (tester) async {
    // Sunucu bir gun yeni bir seviye eklerse ESKI istemci acik kalmali.
    await _sur(tester, yanit: {'durum': 'gelecekteki_seviye'});
    expect(find.text('UYGULAMA ICERIGI'), findsOneWidget);
  });

  // ================= 4) ZORUNLU EKRAN ATLANAMAZ ========================= //

  testWidgets('ZORUNLU ekran GERI DUGMESIYLE atlanamaz', (tester) async {
    await _sur(tester, yanit: {'durum': 'zorunlu', 'magaza_url': _MAGAZA});
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsOneWidget);

    // Sistem geri dugmesi (Android) / kenar jesti (iOS) ayni yoldan gecer.
    final ok = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(ok, isTrue, reason: 'pop YUTULDU (PopScope canPop:false)');
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsOneWidget);
    expect(find.text('UYGULAMA ICERIGI'), findsNothing);
  });

  testWidgets('ARKA PLANA ATIP GERI GELINCE ekran DURUYOR', (tester) async {
    final s = await _sur(tester, yanit: {'durum': 'zorunlu', 'magaza_url': _MAGAZA});
    expect(s.tel.istekler, hasLength(1));

    // Uygulama arka plana atilip geri getirilir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Kontrol YENIDEN kostu ve ekran hâlâ orada.
    expect(s.tel.istekler.length, greaterThan(1),
        reason: 'on plana gelince YENIDEN kontrol edilmeli');
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsOneWidget);
    expect(find.text('UYGULAMA ICERIGI'), findsNothing);
  });

  // ================= 5) ONERILEN: KAPATILABILIR + ERTELEME ============== //

  testWidgets('ONERILEN uyarisi cikar ve uygulama KULLANILABILIR kalir',
      (tester) async {
    await _sur(tester, yanit: {
      'durum': 'onerilen',
      'magaza_url': _MAGAZA,
    });
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsOneWidget);
    expect(find.byKey(const Key('surum-sonra')), findsOneWidget);
    expect(find.byKey(const Key('surum-simdi-guncelle')), findsOneWidget);
    // KULLANMAYA DEVAM EDEBILIR — zorunludan farki tam olarak bu.
    expect(find.text('UYGULAMA ICERIGI'), findsOneWidget);
  });

  testWidgets('"SONRA" uyariyi kapatir ve YENIDEN ACILISTA da CIKMAZ',
      (tester) async {
    final depo = BellekDepo();
    final s = await _sur(tester, yanit: {'durum': 'onerilen'}, depo: depo);
    await tester.tap(find.byKey(const Key('surum-sonra')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsNothing);
    expect(find.text('UYGULAMA ICERIGI'), findsOneWidget);

    // "Uygulama yeniden basladi": AYNI depo, YENI kap.
    await _sur(tester, yanit: {'durum': 'onerilen'}, depo: depo);
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsNothing,
        reason: 'erteleme penceresi icinde her acilista sorulmamali');
    void kullan(Object _) {}
    kullan(s);
  });

  testWidgets('ERTELEME SURESI GECINCE uyari YENIDEN cikar', (tester) async {
    // Erteleme kaydini penceresinin DISINA tarihlendir.
    final eski = DateTime.now()
        .toUtc()
        .subtract(kOnerilenErteleme + const Duration(minutes: 1));
    final depo = BellekDepo({'surum.onerilen_ertelendi': eski.toIso8601String()});
    await _sur(tester, yanit: {'durum': 'onerilen'}, depo: depo);
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsOneWidget);
  });

  testWidgets('ERTELEME ZORUNLU seviyeyi ETKILEMEZ', (tester) async {
    // "Sonra" secenegi zorunlu ekranda ZATEN yok; erteleme kaydi
    // dururken bile ekran cikmali.
    final depo = BellekDepo(
        {'surum.onerilen_ertelendi': DateTime.now().toUtc().toIso8601String()});
    await _sur(tester, yanit: {'durum': 'zorunlu', 'magaza_url': _MAGAZA}, depo: depo);
    expect(find.byKey(const Key('surum-zorunlu-baslik')), findsOneWidget);
  });

  testWidgets('BOZUK erteleme kaydi uyariyi SUSTURMAZ', (tester) async {
    final depo = BellekDepo({'surum.onerilen_ertelendi': 'bozuk-tarih'});
    await _sur(tester, yanit: {'durum': 'onerilen'}, depo: depo);
    expect(find.byKey(const Key('surum-onerilen-baslik')), findsOneWidget);
  });
}
