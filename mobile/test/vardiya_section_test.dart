/// (P239 §5) "Vardiya Durumu" seridi — SU AN GOREVDE OLAN KISILER.
///
/// =========================================================================
/// BU DOSYA YENIDEN YAZILDI — neden
/// =========================================================================
/// Onceki hali `vardiyaKartlari`yi olcuyordu: `GET /shifts` (vardiya
/// TANIMLARI) -> kart. O eslestirici P239 §5'te SILINDI, cunku serit
/// kullanicinin sordugu soruyu ("su an kim gorevde") yanitlamiyordu:
/// tanim, kimsenin atanmadigi bir gunde de ayni goruntuyu veriyordu.
/// Kaynak artik `/vardiya-plani/simdi` — sunucu TENANT SAATINDE hesaplar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/vardiya_seridi.dart';
import 'package:mobile/src/features/shifts/domain/vardiya_plani_models.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

VardiyaKisi _kisi(String id, String ad, String rol) =>
    VardiyaKisi(planId: 'p-$id', userId: id, ad: ad, rol: rol);

const _slot = VardiyaSlot(
  shiftId: 's1',
  shiftAd: 'Sabah Vardiyası',
  baslangicSaat: '06:00:00',
  bitisSaat: '14:00:00',
);

late AppLocalizations trL10n;

void main() {
  setUpAll(() async {
    trL10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('gorevdekiKartlari — /vardiya-plani/simdi → kisi kartlari (SAF)', () {
    test('GOREVDEKILER kart olur: ad + saat araligi + rol', () {
      final kartlar = gorevdekiKartlari(
        l10n: trL10n,
        simdi: VardiyaSimdi(
          gorevdekiVardiya: _slot,
          gorevdekiler: [_kisi('u1', 'Ali Veli', 'security')],
        ),
      );
      expect(kartlar.single.baslik, 'Ali Veli');
      expect(kartlar.single.altBaslik, '06:00–14:00');
      expect(kartlar.single.altBilgi, 'Güvenlik');
      expect(kartlar.single.userId, 'u1');
      expect(kartlar.single.durum, VardiyaDurum.aktif);
    });

    test('KENDI KARTIM CIZILMEZ', () {
      // Kendi gorevde oldugumu zaten biliyorum; kart bana yeni bir sey
      // soylemiyor ve kendi numaramı aramak anlamsiz.
      final kartlar = gorevdekiKartlari(
        l10n: trL10n,
        simdi: VardiyaSimdi(
          gorevdekiVardiya: _slot,
          gorevdekiler: [
            _kisi('u1', 'Ali Veli', 'security'),
            _kisi('ben', 'Ben Kendim', 'security'),
          ],
        ),
        benimUserId: 'ben',
      );
      expect(kartlar.map((k) => k.userId).toList(), ['u1']);
    });

    test('YALNIZ BEN gorevdeysem liste BOSALIR (bolum cizilmez)', () {
      final kartlar = gorevdekiKartlari(
        l10n: trL10n,
        simdi: VardiyaSimdi(
          gorevdekiVardiya: _slot,
          gorevdekiler: [_kisi('ben', 'Ben Kendim', 'security')],
        ),
        benimUserId: 'ben',
      );
      expect(kartlar, isEmpty);
    });

    test('SIRADAKILER KART OLMAZ — serit "su an"i anlatir', () {
      final kartlar = gorevdekiKartlari(
        l10n: trL10n,
        simdi: VardiyaSimdi(
          sonrakiVardiya: _slot,
          sonrakiler: [_kisi('u9', 'Sonraki Kisi', 'security')],
        ),
      );
      expect(kartlar, isEmpty);
    });

    test('SLOT YOKSA alt baslik ROL olur — bos satir birakilmaz', () {
      final kartlar = gorevdekiKartlari(
        l10n: trL10n,
        simdi: VardiyaSimdi(
          gorevdekiler: [_kisi('u1', 'Ali Veli', 'tesis_gorevlisi')],
        ),
      );
      expect(kartlar.single.altBaslik, 'Tesis Görevlisi');
    });
  });

  group('VardiyaSeridi — "Vardiya Durumu" bolumu', () {
    testWidgets('baslik + kartlar cizilir; "Tümünü Gör" cagirir',
        (tester) async {
      var tumu = 0;
      await tester.pumpWidget(_wrap(VardiyaSeridi(
        kartlar: gorevdekiKartlari(
          l10n: trL10n,
          simdi: VardiyaSimdi(
            gorevdekiVardiya: _slot,
            gorevdekiler: [_kisi('u1', 'Ali Veli', 'security')],
          ),
        ),
        onSeeAll: () => tumu++,
      )));

      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('06:00–14:00'), findsOneWidget);
      expect(find.text('AKTİF'), findsOneWidget);

      await tester.tap(find.text('Tümünü Gör'));
      expect(tumu, 1);
    });

    testWidgets('KARTA DOKUNMA kisiyi verir', (tester) async {
      VardiyaKart? secilen;
      await tester.pumpWidget(_wrap(VardiyaSeridi(
        kartlar: gorevdekiKartlari(
          l10n: trL10n,
          simdi: VardiyaSimdi(
            gorevdekiVardiya: _slot,
            gorevdekiler: [_kisi('u1', 'Ali Veli', 'security')],
          ),
        ),
        onKart: (k) => secilen = k,
      )));

      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      expect(secilen?.userId, 'u1');
    });

    testWidgets('KISISIZ KART TIKLANMAZ — "dokundum, bir sey olmadi" olmasin',
        (tester) async {
      var cagri = 0;
      await tester.pumpWidget(_wrap(VardiyaSeridi(
        kartlar: const [
          VardiyaKart(
            baslik: 'Sabah Vardiyası',
            altBaslik: '06:00–14:00',
            durum: VardiyaDurum.planlandi,
            altBilgi: '2 Görevli',
          ),
        ],
        onKart: (_) => cagri++,
      )));

      await tester.tap(find.text('Sabah Vardiyası'));
      await tester.pump();
      expect(cagri, 0);
    });

    testWidgets('bos liste: bolum HIC cizilmez (baslik dahil)', (tester) async {
      await tester.pumpWidget(_wrap(const VardiyaSeridi(kartlar: [])));
      expect(find.text('Vardiya Durumu'), findsNothing);
    });
  });
}
