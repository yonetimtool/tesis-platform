import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/kamera_seridi.dart';
import 'package:mobile/src/features/home/presentation/widgets/odeme_karti.dart';
import 'helpers/l10n_test_app.dart';

Widget _wrap(Widget child) =>
    l10nApp(Scaffold(body: SingleChildScrollView(child: child)));

/// GERCEK `/me/dues` sekli: borcsuz daire — tahakkuk 1.250,00 ve son odeme
/// 05.05.2026, sonraki son-odeme tarihi 05.06.2026.
final _borcsuzUnit = MyDuesUnit(
  unitId: 'u1',
  no: '12',
  tahakkukKurus: 125000,
  odenenKurus: 125000,
  bakiyeKurus: 0,
  assessments: [
    DuesAssessment(
      donem: '2026-05',
      tutarKurus: 125000,
      sonOdemeTarihi: DateTime(2026, 6, 5),
    ),
  ],
  payments: [
    DuesPayment(
      tutarKurus: 125000,
      odemeZamani: DateTime(2026, 5, 5),
      yontem: 'elden',
      durum: 'basarili',
    ),
  ],
);

void main() {
  group('OdemeKarti — "Ödeme ve Aidat Durumu" iki sutun (referans)', () {
    testWidgets('sol sutun tutar + "Ödendi" cipi + son odeme; sag sutun '
        'gelecek odeme + "Geçmiş Ödemeler" butonu', (tester) async {
      var gecmis = 0;
      await tester.pumpWidget(_wrap(OdemeKarti(
        ozet: odemeOzeti([_borcsuzUnit])!,
        onGecmis: () => gecmis++,
      )));

      expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
      expect(find.text('Bu Ayki Aidat'), findsOneWidget);
      expect(find.text('₺1.250,00'), findsNWidgets(2)); // bu ay + gelecek
      expect(find.text('Ödendi'), findsOneWidget);
      expect(find.text('Son Ödeme: 05.05.2026'), findsOneWidget);
      expect(find.text('Gelecek Ödeme'), findsOneWidget);
      expect(find.text('05.06.2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gecmis-odemeler')));
      expect(gecmis, 1);
    });

    testWidgets('borc VARSA kirmizi "Ödenmedi" cipi', (tester) async {
      await tester.pumpWidget(_wrap(OdemeKarti(
        ozet: odemeOzeti([
          MyDuesUnit(
            unitId: 'u1',
            no: '12',
            tahakkukKurus: 125000,
            odenenKurus: 0,
            bakiyeKurus: 125000,
            assessments: [
              DuesAssessment(
                  donem: '2026-05',
                  tutarKurus: 125000,
                  sonOdemeTarihi: DateTime(2026, 6, 5)),
            ],
          ),
        ])!,
        onGecmis: () {},
      )));
      expect(find.text('Ödenmedi'), findsOneWidget);
      expect(find.text('05.06.2026'), findsOneWidget);
    });
  });

  group('odemeOzeti — /me/dues → odeme karti (SAF)', () {
    test('daire yoksa null (mock taban kullanilir)', () {
      expect(odemeOzeti(const []), isNull);
    });

    test('tahakkuk yoksa null', () {
      expect(
          odemeOzeti(const [
            MyDuesUnit(
                unitId: 'u1',
                no: '12',
                tahakkukKurus: 0,
                odenenKurus: 0,
                bakiyeKurus: 0),
          ]),
          isNull);
    });

    test('borc 0 → "Ödendi"; son basarili odeme tarihi gosterilir', () {
      final o = odemeOzeti([
        MyDuesUnit(
          unitId: 'u1',
          no: '12',
          tahakkukKurus: 125000,
          odenenKurus: 125000,
          bakiyeKurus: 0,
          assessments: [
            DuesAssessment(
                donem: '2026-05',
                tutarKurus: 125000,
                sonOdemeTarihi: DateTime(2026, 6, 5)),
          ],
          payments: [
            DuesPayment(
                tutarKurus: 125000,
                odemeZamani: DateTime(2026, 5, 5),
                yontem: 'havale',
                durum: 'basarili'),
          ],
        ),
      ])!;
      expect(o.odendi, isTrue);
      expect(o.sonOdeme, '05.05.2026');
      expect(o.gelecekTarih, '05.06.2026');
    });
  });

  group('KameraSeridi — kamera karti: ad + konum + durum (referans)', () {
    testWidgets('ad/konum + "Canlı"; dokunma KAMERAYI doner', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Camera? secilen;
      await tester.pumpWidget(_wrap(KameraSeridi(
        // GERCEK /cameras yanitindan turer (mock kamera listesi kaldirildi).
        kameralar: const [
          Camera(
            id: 'c1',
            ad: 'Ana Giriş',
            konum: 'Ana Kapı - Giriş',
            streamUrl: 'https://x/1.m3u8',
          ),
          Camera(id: 'c2', ad: 'Otopark', streamUrl: 'https://x/2.m3u8'),
        ],
        onAc: (k) => secilen = k,
      )));

      expect(find.text('Canlı Kamera'), findsOneWidget);
      expect(find.text('Ana Giriş'), findsOneWidget);
      expect(find.text('Ana Kapı - Giriş'), findsOneWidget); // konum satiri
      expect(find.text('Canlı'), findsNWidgets(2));
      expect(find.byIcon(Icons.play_arrow), findsWidgets);

      await tester.tap(find.text('Ana Giriş'));
      expect(secilen?.id, 'c1');
    });

    testWidgets('RTSP (oynatilabilir=false): listede KALIR + "Oynatılamıyor" '
        'rozeti, oynat butonu YOK', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(KameraSeridi(
        kameralar: const [
          Camera(
            id: 'c9',
            ad: 'Arka Bahçe NVR',
            konum: 'NVR kanal 4',
            streamUrl: 'rtsp://nvr/kanal4',
            tur: CameraTur.rtsp,
            oynatilabilir: false,
          ),
        ],
        onAc: (_) {},
      )));

      expect(find.text('Arka Bahçe NVR'), findsOneWidget);
      expect(find.text('Oynatılamıyor'), findsOneWidget);
      expect(find.text('Canlı'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    });

    testWidgets('bos liste: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(
          _wrap(KameraSeridi(kameralar: const [], onAc: (_) {})));
      expect(find.text('Canlı Kamera'), findsNothing);
    });
  });
}
