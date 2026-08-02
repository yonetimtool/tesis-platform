/// Kamera oynatici — yukleniyor / hata + "Yeniden dene" / oynat-durdur /
/// controller yasam dongusu.
///
/// SINIR: `video_player` PLATFORM oynaticisina (Android ExoPlayer / iOS
/// AVPlayer) baglidir ve widget testinde platform eklentisi YOKTUR
/// (`initialize()` hic yanit vermez). Bu yuzden ekran controller uretimini
/// test icin disaridan alir (`controllerYapici`): asagidaki sahtelerle
/// EKRANIN MANTIGI dogrulanir. GERCEK yayin oynatmasi cihazda dogrulanir
/// (seed'deki public HLS/MP4 ornekleri).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/camera_player_screen.dart';
import 'package:video_player/video_player.dart';
import 'helpers/l10n_test_app.dart';

/// Platform'a HIC dokunmayan sahte controller. `initialize` [basarili] ise
/// value'yu "hazir" yapar, degilse firlatir; `dispose` sayilir (sizinti
/// testi).
class _SahteController extends VideoPlayerController {
  _SahteController({required this.basarili})
      : super.networkUrl(Uri.parse('https://sahte/x.m3u8'));

  final bool basarili;
  bool atildi = false;

  @override
  Future<void> initialize() async {
    if (!basarili) throw Exception('yayına ulaşılamadı');
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
  Future<void> setLooping(bool looping) async {}

  @override
  // super.dispose() PLATFORMA gider (sahtede kanal yok) — bilerek cagrilmaz.
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }
}

/// HIC YANIT VERMEYEN oynatici — iOS'ta `AVPlayerItem.status` `.unknown`ta
/// takili kaldigindaki durum: ne hazir olur ne hata verir.
class _AskidaController extends VideoPlayerController {
  _AskidaController() : super.networkUrl(Uri.parse('https://sahte/x.m3u8'));

  bool atildi = false;

  @override
  Future<void> initialize() => Completer<void>().future; // ASLA tamamlanmaz

  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }
}

/// Tamamlanmasini TESTIN belirledigi controller — es zamanli
/// `initialize()` cagrilarini kurmak icin.
class _GecikmeliController extends VideoPlayerController {
  _GecikmeliController(this.etiket)
      : super.networkUrl(Uri.parse('https://sahte/x.m3u8'));

  final int etiket;
  final _kapi = Completer<void>();
  bool atildi = false;

  @override
  Future<void> initialize() async {
    await _kapi.future;
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(minutes: 1),
      size: const Size(1280, 720),
    );
  }

  void tamamla() => _kapi.complete();

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }
}

/// Hazir olur, SONRA hata verir — HLS'in tipik akisi: ana liste yuklenir,
/// oynatici "hazir" olur, sonra varyant/parca ya da kodek reddedilir.
class _SonradanHataController extends VideoPlayerController {
  _SonradanHataController()
      : super.networkUrl(Uri.parse('https://sahte/x.m3u8'));

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
  Future<void> setLooping(bool looping) async {}

  /// Platformun hata olayinin karsiligi.
  void hataVer(String mesaj) => value = VideoPlayerValue.erroneous(mesaj);

  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }
}

const _kamera = Camera(
  id: 'c1',
  ad: 'Ana Kapı',
  konum: 'Ana Kapı - Giriş',
  streamUrl: 'https://test-streams.example/x.m3u8',
);

void main() {
  testWidgets('yayin acilamazsa: "Yayın açılamadı" + oneri + Yeniden dene',
      (tester) async {
    final kurulanlar = <_SahteController>[];
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) {
          final c = _SahteController(basarili: false);
          kurulanlar.add(c);
          return c;
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kamera-hata')), findsOneWidget);
    expect(find.text('Yayın açılamadı'), findsOneWidget);
    expect(
      find.text('Kamera kapalı olabilir ya da ağ yayına ulaşamıyor.'),
      findsOneWidget,
    );
    expect(find.text('Yeniden dene'), findsOneWidget);
    // Baslikta kamera adi + konum.
    expect(find.text('Ana Kapı'), findsOneWidget);
    expect(find.text('Ana Kapı - Giriş'), findsOneWidget);
    // Hata durumunda yukleme gostergesi KALMAZ (sonsuz spinner yok).
    expect(find.byKey(const Key('kamera-yukleniyor')), findsNothing);
    // Basarisiz controller ATILDI (sizinti yok).
    expect(kurulanlar.single.atildi, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yeniden dene: YENI controller kurulur, eskisi atilir',
      (tester) async {
    final kurulanlar = <_SahteController>[];
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) {
          final c = _SahteController(basarili: false);
          kurulanlar.add(c);
          return c;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(kurulanlar, hasLength(1));

    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();

    expect(kurulanlar, hasLength(2), reason: 'yeniden deneme yeni controller');
    expect(kurulanlar.every((c) => c.atildi), isTrue);
    expect(find.text('Yayın açılamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yayin acilinca: spinner YERINE video; dokunma oynat/durdur',
      (tester) async {
    late _SahteController kurulan;
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) => kurulan = _SahteController(basarili: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kamera-yukleniyor')), findsNothing);
    expect(find.byKey(const Key('kamera-hata')), findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(kurulan.value.isPlaying, isTrue, reason: 'acilista oynar');
    // Duraklat → buyuk oynat ikonu belirir. Sahte controller'in Texture'i
    // olculemedigi icin dokunma EKRAN MERKEZINE gonderilir (video yuzeyi
    // govdeyi kaplar).
    await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
    await tester.pumpAndSettle();
    expect(kurulan.value.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('ekrandan cikis: controller ATILIR (sizinti yok)',
      (tester) async {
    late _SahteController kurulan;
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) => kurulan = _SahteController(basarili: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(kurulan.atildi, isFalse);

    await tester.pumpWidget(l10nApp(SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(kurulan.atildi, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTSP bilgi karti: ad + konum + tur + aciklama (oynatici YOK)',
      (tester) async {
    await tester.pumpWidget(
      l10nApp(
        const Scaffold(
          body: CameraBilgiSheet(
            kamera: Camera(
              id: 'c9',
              ad: 'Arka Bahçe NVR',
              konum: 'NVR kanal 4',
              streamUrl: 'rtsp://nvr/k4',
              tur: CameraTur.rtsp,
              oynatilabilir: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arka Bahçe NVR'), findsOneWidget);
    expect(find.text('NVR kanal 4'), findsOneWidget);
    expect(find.text('Tür: RTSP'), findsOneWidget);
    expect(
      find.textContaining('oynatma desteği ileride eklenecek'),
      findsOneWidget,
    );
    // Oynatici acilmadi: video yuzeyi/yukleme gostergesi yok.
    expect(find.byKey(const Key('kamera-yukleniyor')), findsNothing);
  });

  // ---------------- iOS BULGUSU: yayin acilmiyordu ----------------

  testWidgets('ASKIDA KALAN yayin SONSUZ gostergede birakmaz', (tester) async {
    // iOS'ta AVPlayerItem `.unknown`ta takilirsa ne hazir ne hata gelir;
    // `initialize()` HIC tamamlanmaz. Ust sinir olmadan ekran sonsuza
    // kadar donerdi — ve "yeniden dene" YALNIZ hata ekraninda oldugu icin
    // kullanicinin cikistan baska yolu olmazdi.
    late _AskidaController sahte;
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) => sahte = _AskidaController(),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const Key('kamera-yukleniyor')), findsOneWidget);

    // Ust siniri gecir.
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kamera-hata')), findsOneWidget,
        reason: 'zaman asimindan sonra HATA ekrani gelmeli');
    expect(find.byKey(const Key('kamera-yukleniyor')), findsNothing);
    expect(sahte.atildi, isTrue, reason: 'askida controller ATILMALI');
  });

  testWidgets('HAZIRLIK SONRASI hata da ekrana cikar (siyah ekran yok)',
      (tester) async {
    // ESKIDEN HIC YAKALANMIYORDU: `video_player`, hata initialize()
    // tamamlandiktan SONRA gelirse yalnizca `value`yu isaretler. Ekran
    // siyah kalir, uzerinde oynat ikonu durur, kullaniciya hicbir sey
    // soylenmezdi.
    late _SonradanHataController sahte;
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) => sahte = _SonradanHataController(),
      ),
    ));
    await tester.pumpAndSettle();
    // Once OYNUYOR.
    expect(find.byKey(const Key('kamera-hata')), findsNothing);

    sahte.hataVer('The operation could not be completed');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kamera-hata')), findsOneWidget);
    expect(find.byKey(const Key('kamera-hata-neden')), findsOneWidget);
    expect(sahte.atildi, isTrue, reason: 'hatali controller ATILMALI');
  });

  testWidgets('ES ZAMANLI denemede GECIKMIS olan yenisini EZMEZ', (tester) async {
    // ASIL RISK BU. "Yeniden dene" arka arkaya basildiginda birden cok
    // `initialize()` UCUSTA olur. Kusak denetimi olmasaydi GEC BITEN
    // cagri `_controller`i ezerdi ve ezilen oynatici HIC atilmazdi —
    // iOS'ta ses oturumunu tutan hayalet bir AVPlayer kalirdi.
    //
    // NOT: ilk yazimda bu test denemeleri SIRAYLA yapiyordu (her
    // dokunustan sonra `pumpAndSettle`) ve o zaman kusak denetimi HIC
    // devreye girmiyordu — mutasyon denetimi bunu yakaladi, test
    // gercekten es zamanli hale getirildi.
    final uretilenler = <_GecikmeliController>[];
    await tester.pumpWidget(l10nApp(
      CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) {
          final c = _GecikmeliController(uretilenler.length);
          uretilenler.add(c);
          return c;
        },
      ),
    ));
    await tester.pump();
    expect(uretilenler.length, 1);

    // Ilki HENUZ BITMEDEN ikinciyi baslat: ekran gostergede oldugu icin
    // dugme yok — dogrudan durumu yeniden tetikleyecek sekilde ekrani
    // yeniden kur yerine, ilkini bitirmeden ikinci kusagi ac.
    final durum = tester.state<State<CameraPlayerScreen>>(
      find.byType(CameraPlayerScreen),
    );
    // ignore: avoid_dynamic_calls
    (durum as dynamic).baslatTest();
    await tester.pump();
    expect(uretilenler.length, 2, reason: 'ikinci kusak acilmali');

    // SIRAYI TERSINE CEVIR: once YENI biter, sonra ESKI. Kusak denetimi
    // olmasaydi eski, yeniyi ezerdi.
    uretilenler[1].tamamla();
    await tester.pumpAndSettle();
    uretilenler[0].tamamla();
    await tester.pumpAndSettle();

    expect(uretilenler[0].atildi, isTrue,
        reason: 'ESKIMIS kusak atilmali (hayalet oynatici olmasin)');
    expect(uretilenler[1].atildi, isFalse,
        reason: 'GUNCEL oynatici ekranda kalmali');
    expect(find.byKey(const Key('kamera-yukleniyor')), findsNothing);
  });
}
