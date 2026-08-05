import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'helpers/l10n_test_app.dart';

const _mock = MockHomeRepository();

void _ekran(WidgetTester tester, {double h = 2000}) {
  tester.view.physicalSize = Size(400, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

late AppLocalizations trL10n;

void main() {
  setUpAll(() async {
    trL10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('HizliErisimSeridi — gorevli: TEK SIRA yatay 5 kart', () {
    testWidgets('referans kart basliklari ve sayaclari sirayla cizilir',
        (tester) async {
      _ekran(tester);
      await tester.pumpWidget(l10nScaffold(HizliErisimSeridi(
        kartlar: _mock.hizliErisim(HomeVaryant.gorevli),
        onSec: (_) {},
      )));

      expect(find.text('Vardiya Durum'), findsOneWidget);
      expect(find.text('Kargo'), findsOneWidget);
      // Taban SAYI TASIMAZ: bes kartin tamami gercek uca baglidir, sayac
      // gelene kadar iskelet cizilir ('Yakında' etiketi KALMADI).
      expect(find.byType(HomeSayacIskeleti), findsWidgets);
      expect(find.text('Yakında'), findsNothing);
      // Serit yatay kaydirilir — sondaki kartlar goruntude olmayabilir;
      // widget agacinda (ListView) hepsi yaratilir.
      expect(tester.takeException(), isNull);
    });

    testWidgets('gercek sayac gelince iskelet YERINE deger cizilir',
        (tester) async {
      _ekran(tester);
      final kartlar = [
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli))
          k.id == HomeKartId.kargo ? k.sayacla('2 Bekliyor') : k,
      ];
      await tester.pumpWidget(
          l10nScaffold(HizliErisimSeridi(kartlar: kartlar, onSec: (_) {})));

      expect(find.text('2 Bekliyor'), findsOneWidget);
    });

    testWidgets('kart dokunmasi geri bildirilir', (tester) async {
      _ekran(tester);
      HizliErisimKart? secilen;
      await tester.pumpWidget(l10nScaffold(HizliErisimSeridi(
        kartlar: _mock.hizliErisim(HomeVaryant.gorevli),
        onSec: (k) => secilen = k,
      )));
      await tester.tap(find.text('Kargo'));
      expect(secilen?.id, HomeKartId.kargo);
      expect(secilen?.rota, '/kargo');
    });
  });

  group('HizliErisimIzgarasi — sakin/yonetici: 4x2 SABIT izgara', () {
    testWidgets('8 kart da cizilir, tasma yok (400dp genislik)',
        (tester) async {
      _ekran(tester);
      await tester.pumpWidget(l10nScaffold(SizedBox(
        width: 368,
        child: HizliErisimIzgarasi(
          kartlar: _mock.hizliErisim(HomeVaryant.yonetici),
          onSec: (_) {},
        ),
      )));

      for (final baslik in [
        'Vardiya Durumu',
        'Görevler',
        'Aidat Durumu',
        'Otopark Kullanımı',
        'İhlaller',
        // (P142) AD BIRLESTIRME (Kerem onayi): "karo adi ile gittigi
        // ekranin adi ayni olacak". `/complaints`e giden karolarin hepsi
        // ekranin kendi adini ("Talep / Arıza") kullanir; "Sikayetler"
        // adli karo BINA SEMASINA gidiyordu, adi da o oldu.
        'Talep / Arıza',
        'Şikayet Haritası',
        'Raporlar',
      ]) {
        expect(find.text(baslik), findsOneWidget, reason: baslik);
      }
      expect(tester.takeException(), isNull); // RenderFlex overflow yok
    });

    testWidgets('sakin: aidat karti GERCEK /me/dues degeriyle IKI alt satir '
        'tasir (tutar + Borç Yok)', (tester) async {
      _ekran(tester);
      final kartlar = [
        for (final k in _mock.hizliErisim(HomeVaryant.sakin))
          k.id == HomeKartId.aidatBilgileri
              ? k.sayacla('₺1.250,00', yeniIkinciAltMetin: 'Borç Yok')
              : k,
      ];
      await tester.pumpWidget(l10nScaffold(SizedBox(
        width: 368,
        child: HizliErisimIzgarasi(kartlar: kartlar, onSec: (_) {}),
      )));
      expect(find.text('Aidat Bilgileri'), findsOneWidget);
      expect(find.text('₺1.250,00'), findsOneWidget);
      expect(find.text('Borç Yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('sutun esigi IZGARA genisligine gore: tipik telefon 4, cok dar 2', () {
      // 390dp ekran → izgara 358dp → referanstaki gibi 4 sutun.
      expect(hizliErisimSutun(358), 4);
      expect(hizliErisimSutun(328), 4); // 360dp ekran
      expect(hizliErisimSutun(288), 2); // 320dp ekran
    });

    test('serit kart genisligi: telefonda ~4.5 kart gorunur, genis ekranda '
        'spesifikasyonun 110dp\'si', () {
      expect(seritKartGenisligi(390), lessThan(110));
      expect(seritKartGenisligi(390), greaterThanOrEqualTo(84));
      expect(seritKartGenisligi(900), 110);
    });

    testWidgets('bos liste: izgara HIC cizilmez', (tester) async {
      await tester.pumpWidget(l10nScaffold(
          HizliErisimIzgarasi(kartlar: const [], onSec: (_) {})));
      expect(find.byType(HizliErisimKarti), findsNothing);
    });
  });

  group('HizliErisimKart.sayacla — gercek veri mock tabani EZER', () {
    test('sayac degisir; ikon/renk/rota korunur', () {
      const kart = HizliErisimKart(
        ikon: Icons.inventory_2,
        id: HomeKartId.kargo,
        accent: HomeTokens.green,
        altMetin: '5 Bekliyor',
        rota: '/kargo',
      );
      final yeni = kart.sayacla('2 Bekliyor');
      expect(yeni.altMetin, '2 Bekliyor');
      expect(yeni.rota, '/kargo');
      expect(yeni.accent, HomeTokens.green);
      expect(yeni.ikon, Icons.inventory_2);
    });

    test('null sayac: kart AYNEN kalir (veri henuz gelmedi → iskelet)', () {
      const kart = HizliErisimKart(
        ikon: Icons.error_outline,
        id: HomeKartId.ihlaller,
        accent: HomeTokens.red,
        altMetin: null,
      );
      expect(identical(kart.sayacla(null), kart), isTrue);
      expect(kart.altMetin, isNull);
    });
  });
}
