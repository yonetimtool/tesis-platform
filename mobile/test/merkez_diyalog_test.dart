/// P22(a) — MERKEZ DIYALOG kilidi.
///
/// Kerem'in istegi: "tum acilir pencereler ORTADAN acilsin, tek bicim".
/// Bu dosya o istegi UC ayri iddiayla kilitler:
///   1. KAYNAK TARAMASI — `lib` icinde tek bir `showModalBottomSheet`
///      cagrisi bile kalmamali (yeni bir ekran eskiye donerse burada duser).
///   2. DUZEN — pencere gercekten ORTADA acilir, altta degil.
///   3. DAVRANIS — uzun govde KAYDIRIR (alt sayfadan gelen govdelerin
///      kendi `SingleChildScrollView`i sinirsiz yukseklikte viewport 0
///      aliyordu — tur 31'in olcumu) ve klavye boslugu IKI KEZ sayilmaz.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/merkez_diyalog.dart';

import 'helpers/l10n_test_app.dart';

/// Pencereyi acan kucuk kabuk — her testte tekrarlanmasin.
Widget _acici(WidgetBuilder govde, {void Function(Object?)? sonuc}) => l10nApp(
  Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            final d = await merkezSayfaAc<Object?>(context, builder: govde);
            sonuc?.call(d);
          },
          child: const Text('ac'),
        ),
      ),
    ),
  ),
);

/// Pencerenin GORUNEN yuzeyi (perde degil).
final _yuzey = find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

Future<void> _ac(WidgetTester tester) async {
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
}

void main() {
  test('KAYNAK: lib icinde showModalBottomSheet CAGRISI kalmadi', () {
    final kalanlar = <String>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final satirlar = e.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        // BELGE metni degil CAGRI aranir: `merkez_diyalog.dart`in aciklamasi
        // eski adi anlatmak icin geciyor ve gecmeye devam etmeli.
        if (RegExp(r'showModalBottomSheet(<[^>]*>)?\(').hasMatch(satirlar[i])) {
          kalanlar.add('${e.path}:${i + 1}');
        }
      }
    }
    expect(
      kalanlar,
      isEmpty,
      reason:
          'Alt sayfa cagrisi geri geldi (${kalanlar.length}): '
          '${kalanlar.take(5).join(", ")} — `merkezSayfaAc` kullanin.',
    );
  });

  testWidgets('DUZEN: pencere ORTADA acilir (altta degil)', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _acici((_) => const SizedBox(height: 200, child: Text('govde'))),
    );
    await _ac(tester);

    expect(find.byType(Dialog), findsOneWidget);
    // `Dialog`in KENDI kutusu perdeyle birlikte tum ekrani kaplar; olculecek
    // olan icindeki YUZEYDIR (`Material`).
    final r = tester.getRect(_yuzey);
    // Alt sayfa olsaydi merkezi ekranin ALT yarisinda olurdu; merkez
    // diyalogda ekran merkezine ±1 dp yakin durur.
    expect(r.center.dy, closeTo(400, 1));
    // Yatayda da ortalidir ve kenarlara yapismaz (insetPadding 16).
    expect(r.center.dx, closeTo(200, 1));
    expect(r.left, greaterThanOrEqualTo(16));
  });

  testWidgets('KAYDIRMA: uzun govde gercekten kaydirir (viewport > 0)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _acici(
        // Alt sayfa doneminden gelen tipik govde: kendi kaydirma alani var.
        (_) => SingleChildScrollView(
          child: Column(
            children: List.generate(
              40,
              (i) => SizedBox(height: 40, child: Text('satir $i')),
            ),
          ),
        ),
      ),
    );
    await _ac(tester);

    final durum = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      durum.position.viewportDimension,
      greaterThan(0),
      reason: 'viewport 0 — govde sinirsiz yukseklik almis, HIC kaydirmaz',
    );
    expect(
      durum.position.maxScrollExtent,
      greaterThan(0),
      reason: '1600 dp govde 800 dp ekranda kaydirilabilir olmali',
    );
  });

  testWidgets('KLAVYE: alt bosluk IKI KEZ sayilmaz', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    double? icerideki;
    await tester.pumpWidget(
      MediaQuery(
        // Klavye acik: 300 dp alt bosluk.
        data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
        child: _acici((ctx) {
          icerideki = MediaQuery.of(ctx).viewInsets.bottom;
          return const SizedBox(height: 100, child: Text('govde'));
        }),
      ),
    );
    await _ac(tester);

    // `Dialog` bosluğu ZATEN insetPadding'e ekledi; govdeye 0 gitmeli,
    // yoksa govdelerdeki `viewInsets.bottom` dolgusu ikinci kez eklenir.
    expect(icerideki, 0);
    // Pencere klavyenin USTUNDE kalir (800 - 300 = 500 dp'lik alanda).
    expect(tester.getRect(_yuzey).bottom, lessThanOrEqualTo(500));
  });

  testWidgets('DONUS: pop degeri cagirana ulasir', (tester) async {
    Object? alinan;
    await tester.pumpWidget(
      _acici(
        (dctx) => TextButton(
          onPressed: () => Navigator.of(dctx).pop(42),
          child: const Text('kapat'),
        ),
        sonuc: (v) => alinan = v,
      ),
    );
    await _ac(tester);
    await tester.tap(find.text('kapat'));
    await tester.pumpAndSettle();
    expect(alinan, 42);
  });
}
