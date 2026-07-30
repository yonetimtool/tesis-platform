/// TUR 59 — EKSEN KOMBINASYON SURUSUNUN KENDI TESTI.
///
/// `eksenKombinasyonSurusu` ve `animasyonSurusu` ilk kosumda dort ekranda da
/// TEMIZ dondu. Bu bir kanit DEGIL: olcmeyen bir surus de temiz doner. Tur
/// 39'un dersi buydu (yanlis ikona basan surus uc hali ayni ekranda olcmus).
///
/// Burada uc sey kanitlanir:
///  1. Eksen degerleri gercekten AGACA ULASIYOR — `boldText`, `textScaler` ve
///     `devicePixelRatio` widget icinden okunup kaydediliyor ve yedi
///     kombinasyonun HEPSI ayri ayri gorulmus oluyor. (Kritik: `MaterialApp`
///     kendi `MediaQuery`sini eklerse butun kombinasyonlar aynilasirdi.)
///  2. Yalniz BELIRLI bir kombinasyonda tasan bir kusur YAKALANIYOR.
///  3. `animasyonSurusu` HIC DURMAYAN bir ekranda olcum yapabiliyor —
///     `pumpAndSettle` orada zaman asimina duser, yani o ekranlar bugune dek
///     hic olculmemis olurdu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ekran_surus.dart';

/// Yedi kombinasyonda gorulen eksen degerleri buraya yazilir.
final gorulen = <String>{};

Widget _kaydeden(String dil) => MaterialApp(
  home: Builder(
    builder: (context) {
      final mq = MediaQuery.of(context);
      gorulen.add(
        '${mq.size.width.round()}x${mq.size.height.round()} '
        'dpr=${mq.devicePixelRatio} '
        'olcek=${mq.textScaler.scale(10) / 10} '
        'kalin=${mq.boldText}',
      );
      return const SizedBox.shrink();
    },
  ),
);

/// KASITLI KUSUR: yalniz 320 dp genislikte tasar (1000 dp'lik sabit kutu).
/// Daha genis kombinasyonlarda sorun cikmaz — yani surus eksenleri gercekten
/// ayri ayri deniyorsa YAKALAR, yoksa kacirir.
Widget _dar320Tasan(String dil) => MaterialApp(
  home: Scaffold(
    body: Row(
      children: [
        const SizedBox(width: 400, height: 10),
        Container(width: 400, height: 10, color: Colors.red),
      ],
    ),
  ),
);

/// KASITLI KUSUR: yalniz KALIN YAZI acikken tasar.
Widget _kalinTasan(String dil) => MaterialApp(
  home: Builder(
    builder: (context) {
      final kalin = MediaQuery.boldTextOf(context);
      return Scaffold(
        body: Row(children: [SizedBox(width: kalin ? 5000 : 10, height: 10)]),
      );
    },
  ),
);

/// HIC DURMAYAN ekran: sonsuz tekrarlayan animasyon. Belirli bir kareden
/// sonra tasar (yariyi gecince genisleyen kutu).
class _SonsuzAnimasyon extends StatefulWidget {
  const _SonsuzAnimasyon({required this.tasarMi});
  final bool tasarMi;

  @override
  State<_SonsuzAnimasyon> createState() => _SonsuzAnimasyonState();
}

class _SonsuzAnimasyonState extends State<_SonsuzAnimasyon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          children: [
            SizedBox(
              width: widget.tasarMi && _c.value > 0.5 ? 5000 : 10,
              height: 10,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('DEDEKTOR 1: yedi kombinasyon AGACA ulasiyor (hepsi ayri)', (
    tester,
  ) async {
    gorulen.clear();
    await eksenKombinasyonSurusu(tester, _kaydeden);
    // Yedi kombinasyon = yedi AYRI eksen imzasi. Az cikarsa bir eksen
    // (`boldText` ya da `textScaler`) agaca ulasmiyor demektir.
    expect(
      gorulen.length,
      7,
      reason: 'gorulen imzalar:\n${gorulen.join("\n")}',
    );
    // Somut degerler: kalin yazi ve ara olcek gercekten uygulanmis olmali.
    expect(gorulen.any((g) => g.contains('kalin=true')), isTrue);
    expect(gorulen.any((g) => g.contains('olcek=1.3')), isTrue);
    expect(gorulen.any((g) => g.contains('olcek=0.85')), isTrue);
    expect(gorulen.any((g) => g.contains('dpr=3.0')), isTrue);
    // Yatay yerleşim: genislik > yukseklik olan en az bir kombinasyon.
    expect(gorulen.any((g) => g.startsWith('1024x768')), isTrue);
  });

  testWidgets('DEDEKTOR 2: yalniz 320 dp\'de tasan kusuru YAKALAR', (
    tester,
  ) async {
    await expectLater(
      () => eksenKombinasyonSurusu(tester, _dar320Tasan),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('DEDEKTOR 3: yalniz KALIN YAZI ile tasan kusuru YAKALAR', (
    tester,
  ) async {
    await expectLater(
      () => eksenKombinasyonSurusu(tester, _kalinTasan),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('DEDEKTOR 4: animasyonSurusu HIC DURMAYAN ekrani olcer', (
    tester,
  ) async {
    // Once GEREKCE: `pumpAndSettle` bu ekranda zaman asimina duser, yani
    // mevcut surusler bu ekrani hic olcemez.
    await tester.pumpWidget(const _SonsuzAnimasyon(tasarMi: false));
    await expectLater(
      () => tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      ),
      throwsA(isA<FlutterError>()),
    );
    // Simdi kusurlu halini yakaladigini gosterin.
    await expectLater(
      () => animasyonSurusu(
        tester,
        (dil) => const _SonsuzAnimasyon(tasarMi: true),
        bekleyen: true,
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('DEDEKTOR 5: animasyonSurusu SAGLAM ekranda temiz gecer', (
    tester,
  ) async {
    // `bekleyen: true` olmadan bu ekranda surus KENDISI duserdi (ilk
    // surumdeki kusur); bayrakla dogru olcum yapiyor.
    await animasyonSurusu(
      tester,
      (dil) => const _SonsuzAnimasyon(tasarMi: false),
      bekleyen: true,
    );
  });
}
