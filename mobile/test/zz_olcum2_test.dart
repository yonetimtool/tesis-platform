import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // GERCEK FONT: flutter_test varsayilan fontu HER GLIFI KARE EM cizer,
    // genislikleri ~1.8x sisirir. Olcumu o fontla yapmak "Bewohner
    // hinzufugen"i bile tasan gosterirdi.
    final yukleyici = FontLoader('OlcumFont')
      ..addFont(Future.value(
          File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
              .readAsBytesSync()
              .buffer
              .asByteData()));
    await yukleyici.load();
  });
  test('OLCUM: dugme etiketleri kac satira sariyor', () {
    final anahtarlar = File('/tmp/dugme_anahtarlari.txt').readAsLinesSync()
        .where((e) => e.trim().isNotEmpty).toSet();
    final diller = <String, Map<String, String>>{};
    for (final d in ['tr', 'de', 'ru', 'fr', 'es', 'en', 'ar']) {
      final j = jsonDecode(File('lib/l10n/app_$d.arb').readAsStringSync()) as Map;
      diller[d] = {
        for (final e in j.entries)
          if (!e.key.toString().startsWith('@') && e.value is String)
            e.key.toString(): e.value as String
      };
    }
    String render(String s) {
      final m = RegExp(r'\{\w+,\s*plural,(.*)\}\s*$', dotAll: true).firstMatch(s);
      if (m != null) {
        final o = RegExp(r'other\s*\{([^{}]*)\}').firstMatch(m.group(1)!);
        if (o != null) s = o.group(1)!;
      }
      return s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (g) => 'Xxxxxx');
    }
    // Material dugme etiketi: labelLarge 14sp/w500.
    const stil = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'OlcumFont');
    int satir(String metin, double genislik, double olcek) {
      final tp = TextPainter(
        text: TextSpan(text: metin, style: stil),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(olcek),
      )..layout(maxWidth: genislik);
      return tp.computeLineMetrics().length;
    }
    final rapor = StringBuffer();
    for (final k in anahtarlar.toList()..sort()) {
      if (!diller['tr']!.containsKey(k)) continue;
      for (final d in diller.keys) {
        final v = render(diller[d]![k] ?? '');
        if (v.isEmpty) continue;
        // TAM GENISLIK dugme (320dp ekran): 320 - 16*2 kenar - 24*2 ic = 232
        final tam = satir(v, 232, 1.0);
        // IKILI dugme satiri: (320 - 32 - 8) / 2 - 48 = 92
        final ikili = satir(v, 92, 1.0);
        final tamBuyuk = satir(v, 232, 1.3);
        if (tam > 1 || tamBuyuk > 1) {
          rapor.writeln('$k|$d|tam=$tam|tamX1.3=$tamBuyuk|ikili=$ikili|$v');
        }
      }
    }
    File('/tmp/dugme_olcum.txt').writeAsStringSync(rapor.toString());
    debugPrint('OLCUM YAZILDI: ${rapor.toString().split('\n').length} satir');
  });
}
