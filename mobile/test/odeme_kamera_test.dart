import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/kamera_seridi.dart';
import 'package:mobile/src/features/home/presentation/widgets/odeme_karti.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

const _mock = MockHomeRepository();

void main() {
  group('OdemeKarti — "Ödeme ve Aidat Durumu" iki sutun (referans)', () {
    testWidgets('sol sutun tutar + "Ödendi" cipi + son odeme; sag sutun '
        'gelecek odeme + "Geçmiş Ödemeler" butonu', (tester) async {
      var gecmis = 0;
      await tester.pumpWidget(_wrap(OdemeKarti(
        ozet: _mock.odeme(),
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

  group('KameraSeridi — 16:10 yer tutucu + oynat + "Canlı" (referans)', () {
    testWidgets('kamera adlari + canli etiketi; dokunma indeks doner',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      int? secilen;
      await tester.pumpWidget(_wrap(KameraSeridi(
        kameralar: _mock.kameralar(),
        onIzle: (i) => secilen = i,
      )));

      expect(find.text('Canlı Kamera'), findsOneWidget);
      expect(find.text('Ana Giriş'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsWidgets);

      await tester.tap(find.text('Ana Giriş'));
      expect(secilen, 0);
    });

    testWidgets('bos liste: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(
          _wrap(KameraSeridi(kameralar: const [], onIzle: (_) {})));
      expect(find.text('Canlı Kamera'), findsNothing);
    });
  });
}
