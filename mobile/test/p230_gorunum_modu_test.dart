/// (P230 §2) GORUNUM MODU — yasli kullanicilar icin TEK ayar.
///
/// =========================================================================
/// OLCUM (once)
/// =========================================================================
/// Uygulama sistem yazi olcegini ZATEN izliyor: `main.dart`te bir
/// `textScaler` gecersiz kilmasi YOK (arandi). Yani "sistem olcegi
/// izleniyor mu" sorusunun yaniti EVET idi; eksik olan, sistem ayarini
/// BILMEYEN kullanici icin uygulama ici bir yol ve "az oge" karariydi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/gorunum/gorunum_modu.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';

import 'helpers/l10n_test_app.dart';

/// Testte kalici depoya gitmeden buyuk modu zorlayan denetleyici.
class _SabitMod extends GorunumModuController {
  @override
  GorunumModu build() => GorunumModu.buyuk;
}

List<HizliErisimKart> _kartlar(int n) => [
  for (var i = 0; i < n; i++)
    HizliErisimKart(
      id: HomeKartId.values[i % HomeKartId.values.length],
      ikon: Icons.star,
      accent: Colors.blue,
      altMetin: null,
      sayacsiz: true,
    ),
];

Widget _olcekSurusu({required void Function(TextScaler) yakala, bool buyuk = false}) =>
    ProviderScope(
      overrides: [
        if (buyuk) gorunumModuProvider.overrideWith(_SabitMod.new),
      ],
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: l10nApp(
          GorunumOlcegi(
            child: Builder(builder: (c) {
              yakala(MediaQuery.textScalerOf(c));
              return const SizedBox();
            }),
          ),
        ),
      ),
    );

void main() {
  group('mod kurallari', () {
    test('BUYUK MOD: 2 sutun, 4 karo, 1.3 carpan', () {
      expect(GorunumModu.buyuk.izgaraSutun, 2);
      expect(GorunumModu.buyuk.izgaraKaroSiniri, 4);
      expect(GorunumModu.buyuk.metinCarpani, 1.3);
    });

    test('STANDART MOD hicbir seyi DEGISTIRMEZ', () {
      expect(GorunumModu.standart.izgaraSutun, isNull);
      expect(GorunumModu.standart.izgaraKaroSiniri, isNull);
      expect(GorunumModu.standart.metinCarpani, 1.0);
    });

    test('BILINMEYEN DEGER standarda duser', () {
      // Depoda bozuk bir deger uygulamayi acilmaz hale GETIRMEMELI.
      expect(gorunumModuCoz('uydurma'), GorunumModu.standart);
      expect(gorunumModuCoz(null), GorunumModu.standart);
      expect(gorunumModuCoz('buyuk'), GorunumModu.buyuk);
    });
  });

  group('metin olcegi', () {
    testWidgets('SISTEM OLCEGINI EZMEZ, USTUNE CARPAR', (tester) async {
      // EN KRITIK KURAL: sistemde zaten 1.5 kullanan biri buyuk modu
      // acinca 1.3'e DUSMEMELI. Sabit bir olcek yazmak tam olarak bunu
      // yapardi — zaten buyuk yazi kullanan kullanici icin GERILEME.
      late TextScaler icerideki;
      await tester.pumpWidget(
        _olcekSurusu(yakala: (t) => icerideki = t, buyuk: true),
      );
      await tester.pumpAndSettle();
      expect(icerideki.scale(10), closeTo(19.5, 0.01)); // 1.5 x 1.3
    });

    testWidgets('STANDART MODDA olcek DOKUNULMADAN gecer', (tester) async {
      late TextScaler icerideki;
      await tester.pumpWidget(_olcekSurusu(yakala: (t) => icerideki = t));
      await tester.pumpAndSettle();
      expect(icerideki.scale(10), closeTo(15.0, 0.01));
    });
  });

  group('baglanti', () {
    test('HER izgara cagri yeri `mod:` GECIRIR', () {
      // PARAMETRE YAKLASIMININ RISKI: varsayilan `standart` oldugu icin,
      // `mod:` gecirmeyi unutan bir ekran SESSIZCE buyuk modu yok sayar —
      // kullanici ayari acar, o ekranda hicbir sey degismez. Kirmizi bir
      // hata yok, yalniz calismayan bir ozellik var. Bu tarama onu
      // yakalar.
      final kok = Directory('lib/src/features/home/presentation');
      final cagirilar = <String>[];
      for (final f in kok.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('hizli_erisim.dart')) continue; // tanim
        final metin = f.readAsStringSync();
        var i = metin.indexOf('HizliErisimIzgarasi(');
        while (i != -1) {
          // Cagrinin govdesi: acilis parantezinden sonraki ~400 karakter
          // icinde `mod:` gecmeli.
          final pencere = metin.substring(
            i,
            (i + 400).clamp(0, metin.length),
          );
          if (!pencere.contains('mod:')) cagirilar.add(f.path);
          i = metin.indexOf('HizliErisimIzgarasi(', i + 1);
        }
      }
      expect(cagirilar, isEmpty,
          reason: 'bu ekranlar `mod:` gecirmiyor — buyuk mod orada '
              'SESSIZCE calismaz:\n${cagirilar.join("\n")}');
    });
  });

  group('izgara', () {
    testWidgets('BUYUK MOD: 8 karodan 4, TASMA YOK', (tester) async {
      // "AZ OGE" > "KUCUK OGE": sekiz karoyu buyutup ekrana sigdirmaya
      // calismak her karoyu yeniden kuculturdu — ayar HICBIR SEY
      // yapmamis olurdu.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(l10nScaffold(
        HizliErisimIzgarasi(
          kartlar: _kartlar(8),
          onSec: (_) {},
          mod: GorunumModu.buyuk,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HizliErisimKarti), findsNWidgets(4));
    });

    testWidgets('STANDART MOD: sekiz karo da cizilir', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(l10nScaffold(
        HizliErisimIzgarasi(kartlar: _kartlar(8), onSec: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(HizliErisimKarti), findsNWidgets(8));
    });

    testWidgets('BUYUK MOD 320dp DAR EKRANDA da tasmaz', (tester) async {
      // Buyuk mod, P229 §1'de olculen tasmanin yeni bir kaynagi
      // OLMAMALI: yazi 1.3 kat buyurken karo sayisi da yariya iniyor.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: l10nScaffold(
          HizliErisimIzgarasi(
            kartlar: _kartlar(8),
            onSec: (_) {},
            mod: GorunumModu.buyuk,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
