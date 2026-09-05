/// (P213 §4-5) ANA EKRAN KAMERA BANDI — SECIM ve IKI SUTUNLU IZGARA.
///
/// ===========================================================================
/// IKI DEGISIKLIK
/// ===========================================================================
/// §4 SECIM: bant eskiden TUM kamera listesinden besleniyordu; ana ekranda
/// hangi kameranin gorunecegine sunucunun siralamasi karar veriyordu.
/// Artik karar YONETICININ (`ana_ekranda` bayragi) ve suzgec SUNUCUDA
/// uygulaniyor — 20 kamerali bir sitede 20 kamera verisi indirip 4'unu
/// gostermek gereksiz trafikti.
///
/// §5 YERLESIM: bant YATAY KAYDIRMALI bir seritti ve kart genisligi
/// "ekrana DORT kart sigsin" kuralindan turuyordu (P25c). Tipik telefonda
/// kart ~85 dp'ye dusuyor, sagda bos serit kaliyor ve kare neredeyse
/// okunmuyordu. Artik SATIR BASINA IKI kart, genislik TAM DOLDURULUR,
/// ucuncu/dorduncu kamera ALTA gecer.
///
/// YALNIZ BU IZGARA degisti: hizli erisim ve istatistik izgaralarina
/// DOKUNULMADI (asagida ayrica olculuyor).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/kamera_seridi.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, Map<String, dynamic> sorgu})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      yol: options.path,
      sorgu: Map<String, dynamic>.from(options.queryParameters),
    ));
    return ResponseBody.fromString(
      jsonEncode({'items': const [], 'meta': {'total': 0}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Camera _kam(String id, {bool anaEkranda = true}) => Camera(
      id: id,
      ad: 'Kamera $id',
      streamUrl: 'rtsp://gizli:parola@10.0.0.5:554/s',
      tur: CameraTur.rtsp,
      aktif: true,
      anaEkranda: anaEkranda,
    );

void main() {
  // ==================== §4 SECIM SUNUCUDA ============================== //

  test('ANA EKRAN saglayicisi `ana_ekranda=true` SUZGECIYLE ister', () async {
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(kap.dispose);

    await kap.read(anaEkranKameralariProvider.future);
    final istek = tel.istekler.firstWhere((i) => i.yol == '/cameras');
    expect(istek.sorgu['ana_ekranda'], isTrue);
  });

  test('KAMERALAR EKRANI suzgec GONDERMEZ (yonetim ekrani tumunu gorur)',
      () async {
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(kap.dispose);

    await kap.read(camerasProvider.future);
    final istek = tel.istekler.firstWhere((i) => i.yol == '/cameras');
    expect(istek.sorgu.containsKey('ana_ekranda'), isFalse);
  });

  test('`ana_ekranda` yanittan OKUNUR', () {
    expect(
      Camera.fromJson(const {
        'id': 'k1', 'ad': 'A', 'stream_url': 'rtsp://x/y', 'tur': 'rtsp',
        'ana_ekranda': true,
      }).anaEkranda,
      isTrue,
    );
    // Alan YOKSA (eski sunucu) varsayilan KAPALI — bant kendiliginden
    // dolmaz.
    expect(
      Camera.fromJson(const {
        'id': 'k1', 'ad': 'A', 'stream_url': 'rtsp://x/y', 'tur': 'rtsp',
      }).anaEkranda,
      isFalse,
    );
  });

  // ==================== §5 IKI SUTUN, TAM GENISLIK ===================== //

  testWidgets('SATIR BASINA IKI kart ve genislik TAM DOLDURULUR',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(l10nApp(
      SingleChildScrollView(
        child: KameraSeridi(
          kameralar: [_kam('1'), _kam('2'), _kam('3'), _kam('4')],
          onAc: (_) {},
        ),
      ),
    ));
    await tester.pump();

    // Dogrudan olcum: kart genisliklerini SizedBox'lardan okuyoruz.
    // Wrap'in DOGRUDAN cocuklari: her kamera icin bir olculu kutu.
    // (Kart icinde de SizedBox'lar var; `descendant` hepsini toplar ve
    // ilk yazimda 12 kutu bulup testi hakli olarak dusurdu.)
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    final kutular = wrap.children.cast<SizedBox>();
    expect(kutular.length, 4, reason: 'dort kamera dort kart');
    final w = kutular.first.width!;
    // Ekran 400, yatay dolgu 2x16, aralik 12 -> (400-32-12)/2 = 178
    expect(w, closeTo((400 - 32 - 12) / 2, 0.5));
    // IKI kart + aralik, kullanilabilir genisligi TAM doldurur.
    expect(2 * w + 12, closeTo(400 - 32, 0.5));
  });

  testWidgets('UC/DORDUNCU kamera ALTA gecer (Wrap ile)', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(l10nApp(
      SingleChildScrollView(
        child: KameraSeridi(
          kameralar: [_kam('1'), _kam('2'), _kam('3')],
          onAc: (_) {},
        ),
      ),
    ));
    await tester.pump();
    // YATAY KAYDIRMA YOK: eski hâl `ListView(scrollDirection: horizontal)`
    // idi ve ucuncu kart ekranin sagina tasiyordu.
    expect(find.byType(Wrap), findsOneWidget);
  });

  testWidgets('KAMERA YOKSA bolum HIC cizilmez', (tester) async {
    await tester.pumpWidget(l10nApp(
      KameraSeridi(kameralar: const [], onAc: (_) {}),
    ));
    expect(find.byType(Wrap), findsNothing);
  });

  // ==================== §5 KAPSAM: BASKA IZGARA DEGISMEDI ============== //

  test('DIGER IZGARALAR DOKUNULMADI (kaynak kilidi)', () {
    // Istegin acik siniri: "YALNIZ kamera izgarasi degissin". Hizli
    // erisim ve istatistik izgaralari kendi sutun hesaplarini
    // KORUYOR — bunu davranisla olcmek icin uc ayri ekran surmek
    // gerekirdi; burada kaynaktaki kararin YERINDE DURDUGU olculuyor.
    final hizli = File(
      'lib/src/features/home/presentation/widgets/hizli_erisim.dart',
    ).readAsStringSync();
    final stat = File(
      'lib/src/features/home/presentation/widgets/stat_tile.dart',
    ).readAsStringSync();
    expect(hizli, contains('crossAxisCount: sutun'));
    expect(stat, contains('crossAxisCount: sutun'));
    // Kamera bandi ise ARTIK GridView DEGIL: iki sutunlu Wrap.
    final bant = File(
      'lib/src/features/home/presentation/widgets/kamera_seridi.dart',
    ).readAsStringSync();
    expect(bant, contains('kKameraSutun'));
    expect(bant.contains('scrollDirection: Axis.horizontal'), isFalse);
  });
}
