/// (P248 §1-kamera) GECMIS KAMERA KAYDI — mobil ekran.
///
/// Taklit HTTP adapter'inda (P200 dersi: dikis Dio'nun ALTINDA, yani
/// istek yolu/sorgu/govde TEL uzerindeki haliyle olculur). Olculen:
///   * rol gorunurlugu — sunucu `_KAYIT_IZLEYICI` kumesi ile AYNI,
///   * 24 saat siniri istemcide de (istek HIC gitmez),
///   * araliklar + BOSLUKLAR cizimi, "arama desteklenmiyor" != "kayit yok",
///   * oynat istegi govdesi ve OYNATICIYA giden URL + Authorization basligi,
///   * sarma = secilen andan YENI `oynat` istegi,
///   * hazirlik sonrasi hata (jeton dolmasi) -> kaldigi andan BIR KEZ yeniden.
///
/// SINIR: gercek HLS oynatimi (ExoPlayer/AVPlayer) widget testinde yoktur;
/// controller sahtedir. Zincirin sunucu tarafi canli API'de olculdu
/// (rapor), cihaz oynatimi olculemedi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/config/app_config.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/domain/kayit_penceresi.dart';
import 'package:mobile/src/features/cameras/presentation/kamera_kayitlari_screen.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';
import 'package:video_player/video_player.dart';

import 'helpers/l10n_test_app.dart';

class _Istek {
  _Istek(this.metot, this.yol, this.sorgu, this.govde);
  final String metot;
  final String yol;
  final Map<String, dynamic> sorgu;
  final Object? govde;
}

class _Tel implements HttpClientAdapter {
  _Tel(this.yanitlar);

  /// `METOT yol` -> (durum, govde)
  final Map<String, (int, Object)> yanitlar;
  final istekler = <_Istek>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(_Istek(options.method, options.path,
        Map.of(options.queryParameters), options.data));
    final y = yanitlar['${options.method} ${options.path}'] ??
        (
          404,
          {
            'error': {'code': 'not_found', 'message': 'yok'}
          }
        );
    return ResponseBody.fromString(
      jsonEncode(y.$2),
      y.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SahteController extends VideoPlayerController {
  _SahteController(super.adres, this.basliklar) : super.networkUrl();

  final Map<String, String> basliklar;
  bool atildi = false;

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(minutes: 1),
      size: const Size(1280, 720),
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }

  void hataVer() =>
      value = value.copyWith(errorDescription: 'HTTP 401 segment');
}

const _kam = 'aaaaaaaa-0000-0000-0000-000000000001';
const _kam2 = 'aaaaaaaa-0000-0000-0000-000000000002';

Map<String, dynamic> _kamera(String id, String ad, {required bool kayit}) => {
      'id': id,
      'ad': ad,
      'stream_url': 'rtsp://***',
      'tur': 'rtsp',
      'aktif': true,
      'kayit_aktif': kayit,
    };

final _liste = (
  200,
  {
    'items': [
      _kamera(_kam, 'Ana Kapi', kayit: true),
      _kamera(_kam2, 'Otopark', kayit: false),
    ],
    'meta': {'limit': 100, 'offset': 0, 'total': 2},
  }
);

// Sabit "simdi" ve pencere (YEREL saat — kullanici kendi saatini secer).
final _simdi = DateTime(2026, 9, 25, 12, 0);
final _bas = DateTime(2026, 9, 25, 8, 0);
final _bit = DateTime(2026, 9, 25, 10, 0);

String _iso(DateTime t) => t.toUtc().toIso8601String();

class _Kurulum {
  _Kurulum(this.tel, this.controllerlar);
  final _Tel tel;
  final List<_SahteController> controllerlar;
}

Future<_Kurulum> _sur(
  WidgetTester tester,
  Map<String, (int, Object)> yanitlar, {
  DateTime? bas,
  DateTime? bit,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel({'GET /cameras': _liste, ...yanitlar});
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final controllerlar = <_SahteController>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: l10nApp(KameraKayitlariScreen(
        ilkBas: bas ?? _bas,
        ilkBit: bit ?? _bit,
        saat: () => _simdi,
        tokenOkuyucu: () async => 'jeton-123',
        controllerYapici: (adres, basliklar) {
          final c = _SahteController(adres, basliklar);
          controllerlar.add(c);
          return c;
        },
      )),
    ),
  );
  await tester.pumpAndSettle();
  return _Kurulum(tel, controllerlar);
}

Iterable<_Istek> _kayitIstekleri(_Tel tel) =>
    tel.istekler.where((i) => i.yol.contains('/kayit/'));

void main() {
  group('rol gorunurlugu (sunucu _KAYIT_IZLEYICI ile ayni kume)', () {
    test('admin / yonetici / guvenlik amiri gorur; digerleri gormez', () {
      const gorur = {UserRole.admin, UserRole.yonetici, UserRole.guvenlikAmiri};
      for (final r in UserRole.values) {
        expect(
          homeMenuForRole(r).contains(HomeMenuEntry.kameraKayitlari),
          gorur.contains(r),
          reason: '$r',
        );
      }
    });

    test('push/derin bag erisim suzgeci ayni kumeyi izler', () {
      final rota = moduleCardSpec(HomeMenuEntry.kameraKayitlari).route;
      expect(rota, AppRoutes.kameraKayitlari);
      expect(rotaErisilebilir(rota, UserRole.guvenlikAmiri), isTrue);
      expect(rotaErisilebilir(rota, UserRole.yonetici), isTrue);
      expect(rotaErisilebilir(rota, UserRole.security), isFalse);
      expect(rotaErisilebilir(rota, UserRole.resident), isFalse);
      expect(homeMenuGrubu(HomeMenuEntry.kameraKayitlari),
          HomeMenuGrup.guvenlik);
    });
  });

  group('pencere kurali (saf)', () {
    final b = DateTime(2026, 9, 24, 12);
    test('tam 24 saat GECERLI, bir saniye fazlasi GENIS', () {
      expect(
          kayitPenceresiDenetle(b, b.add(const Duration(hours: 24)),
              simdi: _simdi),
          isNull);
      expect(
          kayitPenceresiDenetle(
              b, b.add(const Duration(hours: 24, seconds: 1)),
              simdi: _simdi),
          KayitPencereHatasi.genis);
    });
    test('ters / esit / gelecek', () {
      expect(kayitPenceresiDenetle(b, b, simdi: _simdi),
          KayitPencereHatasi.ters);
      expect(
          kayitPenceresiDenetle(b, b.subtract(const Duration(minutes: 1)),
              simdi: _simdi),
          KayitPencereHatasi.ters);
      expect(
          kayitPenceresiDenetle(_simdi.add(const Duration(minutes: 1)),
              _simdi.add(const Duration(hours: 1)),
              simdi: _simdi),
          KayitPencereHatasi.gelecek);
    });
    test('serit: bosluklar + kirpma + birlestirme', () {
      DateTime s(int h, [int m = 0]) => DateTime(2026, 9, 25, h, m);
      final p = kayitSeridi(s(8), s(10), [
        (bas: s(7, 30), bit: s(8, 20)), // pencereden tasar -> kirpilir
        (bas: s(8, 10), bit: s(8, 30)), // ust uste -> birlesir
        (bas: s(9), bit: s(9, 30)),
      ]);
      expect([for (final x in p) x.dolu], [true, false, true, false]);
      expect(p.first.bas, s(8));
      expect(p.first.bit, s(8, 30));
      expect(p[1].bas, s(8, 30));
      expect(p[1].bit, s(9));
      expect(p.last.bit, s(10));
    });
  });

  group('ekran', () {
    testWidgets('yalniz kaydi ACIK kamera listelenir', (tester) async {
      await _sur(tester, {});
      expect(find.text('Ana Kapi'), findsOneWidget);
      expect(find.text('Otopark'), findsNothing);
    });

    testWidgets('kaydi acik kamera yoksa bos durum', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final tel = _Tel({
        'GET /cameras': (
          200,
          {
            'items': [_kamera(_kam2, 'Otopark', kayit: false)],
            'meta': {'limit': 100, 'offset': 0, 'total': 1},
          }
        ),
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = tel;
      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: l10nApp(const KameraKayitlariScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kayit-kamera-yok')), findsOneWidget);
    });

    testWidgets('24 saatten genis pencere: hata gosterilir, istek GITMEZ',
        (tester) async {
      final k = await _sur(
        tester,
        {},
        bas: DateTime(2026, 9, 24, 8),
        bit: DateTime(2026, 9, 25, 8, 1),
      );
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kayit-pencere-hata')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kayit-izle-tumu')));
      await tester.pumpAndSettle();
      expect(_kayitIstekleri(k.tel), isEmpty);
      expect(k.controllerlar, isEmpty);
    });

    testWidgets('arama: UTC sorgu + araliklar ve BOSLUKLAR cizilir',
        (tester) async {
      final k = await _sur(tester, {
        'GET /cameras/$_kam/kayit/araliklar': (
          200,
          {
            'arama_destekli': true,
            'araliklar': [
              {
                'bas': _iso(DateTime(2026, 9, 25, 8, 15)),
                'bit': _iso(DateTime(2026, 9, 25, 9)),
              },
              {
                'bas': _iso(DateTime(2026, 9, 25, 9, 30)),
                'bit': _iso(DateTime(2026, 9, 25, 10)),
              },
            ],
          }
        ),
      });
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      final ara = _kayitIstekleri(k.tel).single;
      expect(ara.metot, 'GET');
      expect(ara.sorgu, {'bas': _iso(_bas), 'bit': _iso(_bit)});
      expect(find.byKey(const Key('kayit-serit')), findsOneWidget);
      // 08:00-08:15 bos, 08:15-09:00 dolu, 09:00-09:30 bos, 09:30-10:00 dolu
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('kayit-parca-$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('kayit-parca-4')), findsNothing);
      expect(find.text('08:15 – 09:00'), findsOneWidget);
      expect(find.text('09:00 – 09:30'), findsOneWidget);
    });

    testWidgets('arama desteklenmiyor != kayit yok', (tester) async {
      await _sur(tester, {
        'GET /cameras/$_kam/kayit/araliklar': (
          200,
          {'arama_destekli': false, 'araliklar': <Object>[]}
        ),
      });
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kayit-arama-yok')), findsOneWidget);
      expect(find.byKey(const Key('kayit-bulunamadi')), findsNothing);
    });

    testWidgets('bos sonuc: kayit bulunamadi', (tester) async {
      await _sur(tester, {
        'GET /cameras/$_kam/kayit/araliklar': (
          200,
          {'arama_destekli': true, 'araliklar': <Object>[]}
        ),
      });
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kayit-bulunamadi')), findsOneWidget);
    });

    testWidgets('sunucu 403/502 mesaji oldugu gibi gosterilir',
        (tester) async {
      await _sur(tester, {
        'GET /cameras/$_kam/kayit/araliklar': (
          502,
          {
            'error': {
              'code': 'bad_gateway',
              'message': 'Kayit cihazina ulasilamadi.',
            }
          }
        ),
      });
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kayit-arama-hata')), findsOneWidget);
      expect(find.text('Kayit cihazina ulasilamadi.'), findsOneWidget);
    });

    testWidgets(
        'araliga dokun -> oynat govdesi + oynaticiya URL ve Authorization',
        (tester) async {
      const yol = '/cameras/$_kam/kayit/kayitabc/index.m3u8';
      final k = await _sur(tester, {
        'GET /cameras/$_kam/kayit/araliklar': (
          200,
          {
            'arama_destekli': true,
            'araliklar': [
              {
                'bas': _iso(DateTime(2026, 9, 25, 8, 15)),
                'bit': _iso(DateTime(2026, 9, 25, 9)),
              },
            ],
          }
        ),
        'POST /cameras/$_kam/kayit/oynat': (200, {'yol': yol}),
      });
      await tester.tap(find.byKey(const Key('kayit-ara')));
      await tester.pumpAndSettle();
      // Bosluk DOKUNULMAZ (parca 0: 08:00-08:15 bos).
      await tester.tap(find.byKey(const Key('kayit-parca-0')));
      await tester.pumpAndSettle();
      expect(_kayitIstekleri(k.tel).where((i) => i.metot == 'POST'), isEmpty);

      await tester.tap(find.byKey(const Key('kayit-parca-1')));
      await tester.pumpAndSettle();
      final oynat = _kayitIstekleri(k.tel).where((i) => i.metot == 'POST');
      expect(oynat.single.yol, '/cameras/$_kam/kayit/oynat');
      expect(oynat.single.govde, {
        'bas': _iso(DateTime(2026, 9, 25, 8, 15)),
        'bit': _iso(DateTime(2026, 9, 25, 9)),
      });
      final c = k.controllerlar.single;
      expect(c.dataSource, '${AppConfig.apiBaseUrl}$yol');
      expect(c.basliklar, {'Authorization': 'Bearer jeton-123'});
      expect(find.byKey(const Key('kayit-oynat-durdur')), findsOneWidget);
      expect(c.value.isPlaying, isTrue);

      // DURAKLAT / DEVAM (kisa duraklama: ayni oturum, yeni istek yok).
      await tester.tap(find.byKey(const Key('kayit-oynat-durdur')));
      await tester.pump();
      expect(c.value.isPlaying, isFalse);
      await tester.tap(find.byKey(const Key('kayit-oynat-durdur')));
      await tester.pump();
      expect(c.value.isPlaying, isTrue);
      expect(k.controllerlar, hasLength(1));

      // SARMA: +1 dk -> secilen andan YENI oynat istegi (bit ayni).
      await tester.tap(find.byKey(const Key('kayit-ileri')));
      await tester.pumpAndSettle();
      final ikinci =
          _kayitIstekleri(k.tel).where((i) => i.metot == 'POST').last;
      expect(ikinci.govde, {
        'bas': _iso(DateTime(2026, 9, 25, 8, 16)),
        'bit': _iso(DateTime(2026, 9, 25, 9)),
      });
      expect(c.atildi, isTrue, reason: 'eski oynatici atilmali');
      expect(k.controllerlar, hasLength(2));

      // GERI: araligin basindan geriye tasmaz.
      await tester.tap(find.byKey(const Key('kayit-geri')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kayit-geri')));
      await tester.pumpAndSettle();
      final son = _kayitIstekleri(k.tel).where((i) => i.metot == 'POST').last;
      expect((son.govde! as Map)['bas'], _iso(DateTime(2026, 9, 25, 8, 15)));
    });

    testWidgets('oynatma sonrasi hata (jeton dolmasi) -> BIR KEZ yeniden',
        (tester) async {
      const yol = '/cameras/$_kam/kayit/kayitabc/index.m3u8';
      final k = await _sur(tester, {
        'POST /cameras/$_kam/kayit/oynat': (200, {'yol': yol}),
      });
      await tester.tap(find.byKey(const Key('kayit-izle-tumu')));
      await tester.pumpAndSettle();
      expect(k.controllerlar, hasLength(1));
      final govde1 = _kayitIstekleri(k.tel).last.govde;
      expect(govde1, {'bas': _iso(_bas), 'bit': _iso(_bit)});

      k.controllerlar.first.hataVer();
      await tester.pumpAndSettle();
      expect(k.controllerlar, hasLength(2), reason: 'kendiliginden yeniden');
      expect(find.byKey(const Key('kayit-hata')), findsNothing);

      // Ikinci hata: artik kullaniciya gosterilir, sonsuz dongu yok.
      k.controllerlar.last.hataVer();
      await tester.pumpAndSettle();
      expect(k.controllerlar, hasLength(2));
      expect(find.byKey(const Key('kayit-hata')), findsOneWidget);
      expect(find.byKey(const Key('kayit-yeniden')), findsOneWidget);
    });

    testWidgets('oynat 422 (sunucu siniri) mesaji oynaticida gosterilir',
        (tester) async {
      final k = await _sur(tester, {
        'POST /cameras/$_kam/kayit/oynat': (
          422,
          {
            'error': {
              'code': 'validation_error',
              'message': 'Bu kamerada gecmis kayit izleme kapali.',
            }
          }
        ),
      });
      await tester.tap(find.byKey(const Key('kayit-izle-tumu')));
      await tester.pumpAndSettle();
      expect(k.controllerlar, isEmpty);
      expect(find.text('Bu kamerada gecmis kayit izleme kapali.'),
          findsOneWidget);
    });
  });

  group('yerlesim: dar ekran, 7 dil (tasma = test hatasi)', () {
    for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      testWidgets('$dil: liste + serit + oynatici tasmaz', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final tel = _Tel({
          'GET /cameras': _liste,
          'GET /cameras/$_kam/kayit/araliklar': (
            200,
            {
              'arama_destekli': true,
              'araliklar': [
                {
                  'bas': _iso(DateTime(2026, 9, 24, 23, 15)),
                  'bit': _iso(DateTime(2026, 9, 25, 9)),
                },
              ],
            }
          ),
          'POST /cameras/$_kam/kayit/oynat': (
            200,
            {'yol': '/cameras/$_kam/kayit/kayitabc/index.m3u8'}
          ),
        });
        final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = tel;
        await tester.pumpWidget(ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: l10nApp(
            KameraKayitlariScreen(
              // Gun asan pencere: tarihli (en uzun) bicim cizilir.
              ilkBas: DateTime(2026, 9, 24, 22),
              ilkBit: _bit,
              saat: () => _simdi,
              tokenOkuyucu: () async => 't',
              controllerYapici: _SahteController.new,
            ),
            locale: Locale(dil),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('kayit-ara')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('kayit-serit')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('kayit-parca-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('kayit-parca-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('kayit-cubuk')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  tearDown(() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  });
}
