/// (P247 §7) KART ETIKETI KILIDI — TEK KELIME ASLA BOLUNMEZ, iOS FONTUYLA.
///
/// =========================================================================
/// P239 KILIDI NEDEN YESILDI, iOS NEDEN "Rezervasyo / n" CIZIYORDU
/// =========================================================================
/// P239 kilidi (`p239_kelime_bolunmesi_test`) SAF FONKSIYONU olcuyordu:
/// punto secicinin kendi olcum stiliyle (`TextStyle(fontSize: p)`) yine
/// kendisini dogruluyordu. Kartin GERCEKTE cizdigi stil ise ucuncu bir
/// seydi: `HomeText.cardTitle` (w600) + temanin `bodyMedium`undan miras
/// kalan `letterSpacing: 0.25` + platform ailesi. iOS'ta olcum SF Pro
/// REGULAR, harf araliksiz yapiliyor; cizim SF Pro SEMIBOLD, 0.25
/// aralikla. "Rezervasyon" (11 harf) olcumde sigdi, cizimde ~3-4 px tasti
/// ve son "n" alt satira dustu. Test ortaminda goremedik cunku test fontu
/// her harfi KARE (1 em) cizer — olcum ondan ZATEN genis cikiyordu.
///
/// Bu kilit fonksiyonu degil CIZILEN WIDGET'I olcer: gercek izgarayi
/// kurar, her `RenderParagraph`in satirlarini karakter karakter cikarir
/// ve satir sonunun kelime siniri oldugunu dogrular.
///
/// =========================================================================
/// FONT: DejaVu Sans Bold (test/fonts/, Bitstream Vera lisansi)
/// =========================================================================
/// SF Pro lisans geregi repoya konamaz. DejaVu Sans Bold, olculen
/// kelimelerde Roboto SemiBold'dan %23-33 GENIS (bu dosyadaki
/// `FONT GENISLIGI` testi olcer ve kilitler). SF Pro Text Semibold ise
/// Roboto'dan yalniz birkac yuzde genistir; yani bu font iOS'u UST
/// SINIRDAN temsil eder — burada kirilmayan etiket iOS'ta da kirilmaz.
/// Tek yuz (Bold) yuklenir: her agirlik ondan cizilir, bu da bilincli
/// olarak en genis durumu secmektir.
///
/// Font `CupertinoSystemText`/`CupertinoSystemDisplay` ADIYLA yuklenir ve
/// platform iOS'a cevrilir: Material'in iOS tipografisi TAM BU aileleri
/// ister. Yani kart, cihazdaki gibi "tema ailesi + w600 + 0.25 aralik"
/// zinciriyle cizilir; test icin ozel bir stil yolu YOKTUR.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/core/theme/app_theme.dart';
import 'package:mobile/src/core/ui/kelime_bolunmez.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/izgara_koprusu.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/features/home/presentation/widgets/stat_tile.dart';
import 'package:mobile/src/core/gorunum/gorunum_modu.dart';

import 'helpers/l10n_test_app.dart';

const _genisFont = 'test/fonts/DejaVuSans-Bold.ttf';
const _robotoKlasoru = 'bin/cache/artifacts/material_fonts';

Future<void> _yukle(String aile, String yol) async {
  final bayt = File(yol).readAsBytesSync();
  final y = FontLoader(aile)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bayt).buffer)));
  await y.load();
}

/// Tire / egik cizgiden SONRA bolunme mesrudur (P239 kurali).
const _mesruSonlar = {'-', '/', '‐', '–', '—'};

/// Cizilmis bir paragrafta kelime ICINDEN satir sonlarini bulur.
List<String> _bolunmeler(RenderParagraph p) {
  final metin = p.text.toPlainText();
  final bulgular = <String>[];
  double? oncekiY;
  for (var i = 0; i < metin.length; i++) {
    final y = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
    if (oncekiY != null && (y - oncekiY).abs() > 0.5) {
      final a = metin[i - 1];
      final b = metin[i];
      if (a.trim().isNotEmpty &&
          b.trim().isNotEmpty &&
          !_mesruSonlar.contains(a)) {
        bulgular.add('${metin.substring(0, i)} | ${metin.substring(i)}');
      }
    }
    oncekiY = y;
  }
  return bulgular;
}

/// TUM kart etiketleri: her menu girisinin karti + her rol varyantinin
/// taban kartlari (sayacli, kimlikten adli olanlar dahil).
List<HizliErisimKart> _tumKartlar() {
  const repo = MockHomeRepository();
  final kartlar = <HizliErisimKart>[
    for (final e in HomeMenuEntry.values) izgaraKartiUret(e, const []),
    for (final v in HomeVaryant.values) ...repo.hizliErisim(v),
  ];
  return kartlar;
}

Widget _sahne({
  required Locale dil,
  required GorunumModu mod,
  required List<HizliErisimKart> kartlar,
}) {
  // Buyuk mod izgarada 4 karo gosterir: tum etiketleri gecirmek icin
  // kartlar DORTLU gruplarla ayri izgaralara bolunur (her biri gercek
  // `HizliErisimIzgarasi`; grup/punto paylasimi uretimdeki gibi).
  final gruplar = <List<HizliErisimKart>>[
    for (var i = 0; i < kartlar.length; i += 4)
      kartlar.sublist(i, (i + 4).clamp(0, kartlar.length)),
  ];
  return MaterialApp(
    locale: dil,
    supportedLocales: supportedLocales,
    localizationsDelegates: testLocalizationsDelegates,
    theme: buildLightTheme(),
    // GorunumOlcegi'nin carpimini yalniz MediaQuery ile verir (sistem 1.0
    // x 1.3): ProviderScope gerektirmeden AYNI olcek.
    builder: (context, cocuk) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(mod.metinCarpani),
      ),
      child: cocuk!,
    ),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final g in gruplar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HizliErisimIzgarasi(kartlar: g, onSec: (_) {}, mod: mod),
            ),
          HizliOzetIzgarasi(kutular: const MockHomeRepository().ozet()),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    for (final aile in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await _yukle(aile, _genisFont);
    }
  });

  const diller = ['tr', 'en', 'de', 'fr', 'es', 'ru', 'ar'];

  for (final genislik in [320.0, 390.0]) {
    for (final mod in GorunumModu.values) {
      testWidgets(
          'KART ETIKETLERI kelime icinden BOLUNMEZ — 7 dil, ${genislik.toInt()}dp, '
          '${mod.name}, genis font', (tester) async {
        tester.view.physicalSize = Size(genislik, 20000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final kartlar = _tumKartlar();
        final ihlaller = <String>[];
        var olculen = 0;
        for (final dil in diller) {
          await tester.pumpWidget(
              _sahne(dil: Locale(dil), mod: mod, kartlar: kartlar));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$dil tasma');
          for (final tip in [HizliErisimKarti, StatTile]) {
            final paragraflar = find.descendant(
              of: find.byType(tip),
              matching: find.byType(RichText),
            );
            for (final e in paragraflar.evaluate()) {
              final p = e.renderObject! as RenderParagraph;
              if (p.text.toPlainText().trim().isEmpty) continue;
              olculen++;
              for (final b in _bolunmeler(p)) {
                ihlaller.add('$dil: $b');
              }
            }
          }
        }
        expect(olculen, greaterThan(500), reason: 'tarama gercekten kosmali');
        expect(ihlaller.toSet().toList(), isEmpty,
            reason: 'kelime ICINDEN bolunen etiketler:\n'
                '${ihlaller.toSet().join("\n")}');
      },
          // iOS: Material'in iOS tipografisi `CupertinoSystemText` ister —
          // genis font o adla yuklu. `debugDefaultTargetPlatformOverride`
          // elle kurulsaydi cerceve "debug degiskeni degisti" diye duserdi.
          variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }

  testWidgets('KOK NEDEN: olcum stili != cizim stili -> "Rezervasyo | n"',
      (tester) async {
    // iOS'un durumu, tek degiskenle: olcum ve cizim AYNI aileyle (iOS'ta
    // stilsiz TextPainter de SF Pro kullanir), ama cizim temadan miras
    // `letterSpacing: 0.25` tasir. Hucre, eski olcume gore 14 puntonun
    // TAM sigdigi genislikte kurulur.
    const aile = TextStyle(fontFamily: 'CupertinoSystemText');
    const cizim = TextStyle(
        fontFamily: 'CupertinoSystemText',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25);
    const kelime = 'Rezervasyon';
    final tp = TextPainter(
      text: TextSpan(text: kelime, style: aile.copyWith(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    final hucre = tp.width + 1.5;
    tp.dispose();

    List<String> bolunme(double punto) {
      final p = TextPainter(
        text: TextSpan(text: kelime, style: cizim.copyWith(fontSize: punto)),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: hucre);
      final satirlar = p.computeLineMetrics().length;
      p.dispose();
      return satirlar > 1 ? ['$kelime @$punto: $satirlar satir'] : [];
    }

    // ESKI: aile dogru ama agirlik/aralik YOK -> 14 secilir, cizim bolunur.
    final eski = kartBaslikPuntosu(kelime, hucre + 1.0, stil: aile);
    expect(eski, 14);
    expect(bolunme(eski!), isNotEmpty, reason: 'kusur yeniden uretilemedi');
    // YENI: cizilen stille olculur -> daha kucuk punto, bolunme yok.
    final yeni = kartBaslikPuntosu(kelime, hucre, stil: cizim);
    expect(yeni, isNotNull);
    expect(yeni!, lessThan(14));
    expect(bolunme(yeni), isEmpty);
  });

  test('FONT GENISLIGI: test fontu Roboto SemiBold\'dan EN AZ %15 genis', () async {
    // Kilidin iOS'u UST SINIRDAN temsil ettigi iddiasi burada olculur.
    // SF Pro Text Semibold Roboto'dan birkac yuzde genistir; %15 esik bu
    // farki rahatca kapsar. Font degistirilirse ve esik altina duserse
    // kilit iOS'u temsil etmez hale gelir — kirmizi olur.
    // `flutter test` FLUTTER_ROOT'u ortama koyar; Roboto SDK ile gelir.
    final flutterKoku = Platform.environment['FLUTTER_ROOT'] ?? '';
    final roboto = '$flutterKoku/$_robotoKlasoru/Roboto-Medium.ttf';
    if (!File(roboto).existsSync()) {
      markTestSkipped('Roboto bulunamadi: $roboto');
      return;
    }
    await _yukle('OlcumRoboto', roboto);
    await _yukle('OlcumGenis', _genisFont);
    double w(String s, String aile) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: aile, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final g = tp.width;
      tp.dispose();
      return g;
    }

    for (final k in ['Rezervasyon', 'Görüntüleme', 'Бронирование',
        'Reservierungen', 'الحجوزات']) {
      final oran = w(k, 'OlcumGenis') / w(k, 'OlcumRoboto');
      expect(oran, greaterThan(1.15), reason: '$k oran=$oran');
    }
  });
}
