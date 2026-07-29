/// TUR 57 — TINT ZEMIN KONTRASTI: HESAPLA, GORUNTUYE GUVENME.
///
/// Tur 52'nin dersi: `textContrastGuideline` KUCUK/INCE metinde yetersiz.
/// Kilavuz cizilen piksellerin histogramindan MOD alir; rozet kucuk ve yazi
/// ince oldugunda baskin renkler zemin tonlari cikar ve ihlal GORUNMEZ.
/// Somut ornek: indigo `#3949AB`, koyu temada %12 tint zemin uzerinde
/// **2.06:1** (esik 4.5) — kilavuz bunu GECIRDI.
///
/// Bu test goruntuye degil MATEMATIGE bakar: "tint zemin" kalibindaki her
/// vurgu rengi icin WCAG kontrast oranini hesaplar ve `okunurVurgu`nun iki
/// temada da esigi tuttugunu dogrular. Yeni bir vurgu rengi eklenirse
/// [vurgular] listesine yazilmali.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/app_theme.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';

/// Uygulamada tint zemin uzerinde METIN olarak kullanilan vurgu renkleri.
const vurgular = <String, Color>{
  'Colors.red': Colors.red,
  'Colors.green': Colors.green,
  'Colors.orange': Colors.orange,
  'Colors.deepOrange': Colors.deepOrange,
  'Colors.blue': Colors.blue,
  'Colors.blueGrey': Colors.blueGrey,
  'HomeTokens.primary': HomeTokens.primary,
  'HomeTokens.green': HomeTokens.green,
  'HomeTokens.orange': HomeTokens.orange,
  'HomeTokens.purple': HomeTokens.purple,
  'HomeTokens.red': HomeTokens.red,
  'marka indigo': Color(0xFF3949AB),
};

/// Kodda kullanilan tint opakliklari.
const opakliklar = <double>[0.08, 0.10, 0.12, 0.15];

/// WCAG 2.1 rolatif parlaklik.
double _parlaklik(Color c) {
  double k(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * k(c.r) + 0.7152 * k(c.g) + 0.0722 * k(c.b);
}

double kontrast(Color a, Color b) {
  final la = _parlaklik(a), lb = _parlaklik(b);
  final ust = math.max(la, lb), alt = math.min(la, lb);
  return (ust + 0.05) / (alt + 0.05);
}

/// [ust] rengini [alt] zeminine [a] opakligiyla karistir (tint zemin).
Color karistir(Color ust, Color alt, double a) => Color.from(
      alpha: 1,
      red: ust.r * a + alt.r * (1 - a),
      green: ust.g * a + alt.g * (1 - a),
      blue: ust.b * a + alt.b * (1 - a),
    );

void main() {
  /// `okunurVurgu` bir `BuildContext` ister; tema basina bir kez cizilir.
  Future<Map<String, Color>> cozulenler(WidgetTester tester, ThemeData tema) async {
    final out = <String, Color>{};
    await tester.pumpWidget(MaterialApp(
      theme: tema,
      home: Builder(builder: (context) {
        for (final e in vurgular.entries) {
          out[e.key] = okunurVurgu(context, e.value);
        }
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();
    return out;
  }

  testWidgets('HAM vurgu rengi tint zemin uzerinde ESIGI TUTMUYOR (kanit)',
      (tester) async {
    // Bu test DUZELTMENIN GEREKCESIDIR: ham renklerin gercekten basarisiz
    // oldugunu kayda gecirir. Basarisiz kombinasyon KALMAZSA (birileri
    // paleti degistirirse) test duser ve gerekce gozden gecirilir.
    final basarisiz = <String>[];
    for (final tema in [buildLightTheme(), buildDarkTheme()]) {
      final yuzey = tema.colorScheme.surface;
      for (final e in vurgular.entries) {
        for (final a in opakliklar) {
          final oran = kontrast(e.value, karistir(e.value, yuzey, a));
          if (oran < 4.5) {
            basarisiz.add('${e.key} @$a ${tema.brightness.name}: '
                '${oran.toStringAsFixed(2)}');
          }
        }
      }
    }
    expect(basarisiz, isNotEmpty,
        reason: 'ham renkler artik esigi tutuyorsa `okunurVurgu` gereksiz '
            'olabilir — gerekce gozden gecirilmeli');
  });

  testWidgets('okunurVurgu HER vurgu x HER opaklik x IKI tema = >= 4.5',
      (tester) async {
    final bulgular = <String>[];
    for (final tema in [buildLightTheme(), buildDarkTheme()]) {
      final cozum = await cozulenler(tester, tema);
      final yuzey = tema.colorScheme.surface;
      for (final e in vurgular.entries) {
        for (final a in opakliklar) {
          final zemin = karistir(e.value, yuzey, a);
          final oran = kontrast(cozum[e.key]!, zemin);
          if (oran < 4.5) {
            bulgular.add('${e.key} @$a ${tema.brightness.name}: '
                '${oran.toStringAsFixed(2)} < 4.5');
          }
        }
      }
    }
    expect(bulgular, isEmpty,
        reason: 'okunurVurgu bu kombinasyonlarda WCAG AA tutmuyor:\n'
            '${bulgular.join("\n")}');
  });
}
