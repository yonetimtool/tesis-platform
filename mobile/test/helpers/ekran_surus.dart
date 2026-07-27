// TUR 23 — EKRAN SURUSU: mevcut test kosumlarindaki ekranlari 7 dilde cizip
// GORUNEN metni tara. ARB denetimi sozlugu olcer; bu, EKRANI olcer:
// sozlukte olmayan (kaynakta unutulmus) sabitleri ancak bu yakalar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
final _trHarf = RegExp('[ğışĞİŞ]');
/// Turkce DISI diller — surusun asil hedefi (tr'de sizinti kavrami yok).
const surusDilleri = ['en', 'ar', 'ru', 'de', 'fr', 'es'];

/// Cizili agactaki TUM Text/RichText metinlerini toplar.
List<String> gorunenMetinler(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.allWidgets) {
    if (w is Text && w.data != null) out.add(w.data!);
    if (w is RichText) {
      final s = w.text.toPlainText();
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}

/// Marka + kullanici VERISI disinda Turkce sabit var mi?
void trSizintisiYok(WidgetTester tester, String dil, {Set<String> veri = const {}}) {
  for (final m in gorunenMetinler(tester)) {
    if (veri.any(m.contains)) continue;           // sunucu/test VERISI
    // MARKA KILIDI (README §15): kelime isareti + logo alt basligi.
    if (m.contains('Yönetio') || m.contains('GÜVENLİK & DANIŞMANLIK')) continue;
    expect(_trHarf.hasMatch(m), isFalse, reason: '$dil ekraninda TR: "$m"');
  }
}
