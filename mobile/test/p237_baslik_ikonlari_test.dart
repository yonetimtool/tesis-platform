/// (P237 §1) BASLIK CUBUGU IKONLARI — ETIKETSIZ GEZINME YASAK.
///
/// Kural: app bar'daki bir eylem BASKA BIR EKRANA goturuyorsa adini
/// GORUNUR tasimali. Tooltip yetmez — mobilde uzun basmayi gerektirir ve
/// olcum (P154/P237) kullanicilarin o ikonlarin varligini hic ogrenmedigini
/// gosterdi. Yerinde is yapan eylemler (yenile, ekle) bu kuralin disinda:
/// ikonlari evrensel ve sonuc ANINDA gorunuyor.
///
/// KILIT KAYNAK TARAR. Davranis testi bu kurali yakalayamaz: etiketsiz bir
/// ikon da mukemmel calisir — kusur ANLASILIRLIKTA, davranista degil.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `actions: [ ... ]` bloklarindaki BASKA EKRANA GIDEN eylemler.
List<String> etiketsizGezinmeler(String kaynak, String yol) {
  final ihlaller = <String>[];
  for (final m in RegExp(r'actions:\s*\[').allMatches(kaynak)) {
    var i = m.end;
    var derinlik = 1;
    while (i < kaynak.length && derinlik > 0) {
      if (kaynak[i] == '[') derinlik++;
      if (kaynak[i] == ']') derinlik--;
      i++;
    }
    final blok = kaynak.substring(m.end, i);
    final widgetler = RegExp(
      r'\b(IconButton|PopupMenuButton|TextButton\.icon|FilledButton\.icon|OutlinedButton\.icon)\b',
    );
    for (final w in widgetler.allMatches(blok)) {
      var j = blok.indexOf('(', w.end);
      if (j < 0) continue;
      var d = 1;
      var k = j + 1;
      while (k < blok.length && d > 0) {
        if (blok[k] == '(') d++;
        if (blok[k] == ')') d--;
        k++;
      }
      final arg = blok.substring(j, k);
      final gezinme = RegExp(
        r'context\.push|Navigator\.of\(context\)\.push|MaterialPageRoute',
      ).hasMatch(arg);
      if (!gezinme) continue;
      // ETIKETLI SAYILAN BICIMLER:
      //  - `label:` → TextButton.icon / FilledButton.icon
      //  - `itemBuilder` → tasma menusu; maddeleri metin tasir
      //  - `child:` → govdesinde metin olan ozel dugme
      final etiketli = arg.contains('label:') ||
          arg.contains('itemBuilder') ||
          arg.contains('child:');
      if (!etiketli) {
        final satir =
            '\n'.allMatches(kaynak.substring(0, m.end + w.start)).length + 1;
        ihlaller.add('$yol:$satir ${w.group(1)}');
      }
    }
  }
  return ihlaller;
}

void main() {
  test('APP BAR: baska ekrana goturen ETIKETSIZ eylem YOK', () {
    final ihlaller = <String>[];
    var taranan = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      taranan++;
      ihlaller.addAll(etiketsizGezinmeler(f.readAsStringSync(), f.path));
    }
    expect(taranan, greaterThan(200), reason: 'tarama gercekten kosmali');
    expect(ihlaller, isEmpty,
        reason: 'Etiketsiz gezinme ikonu: ${ihlaller.join(", ")}');
  });

  group('DEDEKTOR — kilidin kirilabilir oldugunu kanitlar', () {
    test('etiketsiz IconButton + context.push YAKALANIR', () {
      const k = '''
        actions: [
          IconButton(
            tooltip: l10n.birsey,
            icon: const Icon(Icons.abc),
            onPressed: () => context.push(AppRoutes.birsey),
          ),
        ],
      ''';
      expect(etiketsizGezinmeler(k, 'x.dart'), hasLength(1));
    });

    test('TextButton.icon (label) TEMIZ', () {
      const k = '''
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.abc),
            label: Text(l10n.birsey),
            onPressed: () => context.push(AppRoutes.birsey),
          ),
        ],
      ''';
      expect(etiketsizGezinmeler(k, 'x.dart'), isEmpty);
    });

    test('YERINDE is yapan etiketsiz ikon TEMIZ (yenile)', () {
      const k = '''
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ''';
      expect(etiketsizGezinmeler(k, 'x.dart'), isEmpty);
    });

    test('ETIKETLI maddeleri olan tasma menusu TEMIZ', () {
      const k = '''
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (yol) => context.push(yol),
            itemBuilder: (_) => [],
          ),
        ],
      ''';
      expect(etiketsizGezinmeler(k, 'x.dart'), isEmpty);
    });
  });
}
