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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/camera_player_screen.dart';
import 'package:video_player/video_player.dart';

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
    await tester.pumpWidget(MaterialApp(
      home: CameraPlayerScreen(
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
    await tester.pumpWidget(MaterialApp(
      home: CameraPlayerScreen(
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
    await tester.pumpWidget(MaterialApp(
      home: CameraPlayerScreen(
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
    await tester.pumpWidget(MaterialApp(
      home: CameraPlayerScreen(
        kamera: _kamera,
        controllerYapici: (_) => kurulan = _SahteController(basarili: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(kurulan.atildi, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(kurulan.atildi, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTSP bilgi karti: ad + konum + tur + aciklama (oynatici YOK)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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
}
