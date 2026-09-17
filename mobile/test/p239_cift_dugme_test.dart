/// (P239 §6) BOS DURUMDA CIFT CAGRI DUGMESI OLMAZ.
///
/// =========================================================================
/// OLCULEN KUSUR
/// =========================================================================
/// Devriye planlari ekraninda plan yokken hem sayfa ORTASINDA "Plan ekle"
/// hem sag altta FAB vardi. Plan eklenince ortadaki kayboluyor, sag
/// alttaki kaliyor — kullanici ayni eylemi once iki yerde goruyor, sonra
/// "dugme nereye gitti" diye ariyor.
///
/// TARAMA DEVRIYEDEN FAZLASINI BULDU: ayni kalip DORT ekranda vardi
/// (sakinler, devriye planlari, personel, kontrol noktalari). Kullanici
/// birini bildirdi; kilit SINIFI kapatiyor.
///
/// Aciklama metni KALIR — bos liste karsisindaki kullanici cogu zaman
/// ozelligin ne oldugunu da bilmiyor.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `floatingActionButton` TASIYAN bir ekranda `BosDurum(... onEylem: ...)`
/// varsa cift dugme demektir.
List<String> ciftDugmeler(String kaynak, String yol) {
  if (!kaynak.contains('floatingActionButton')) return const [];
  final bulgular = <String>[];
  for (final m in RegExp(r'BosDurum\(').allMatches(kaynak)) {
    var d = 1;
    var k = kaynak.indexOf('(', m.end - 1) + 1;
    final bas = k;
    while (k < kaynak.length && d > 0) {
      if (kaynak[k] == '(') d++;
      if (kaynak[k] == ')') d--;
      k++;
    }
    final arg = kaynak.substring(bas, k);
    if (arg.contains('onEylem')) {
      final satir = '\n'.allMatches(kaynak.substring(0, m.start)).length + 1;
      bulgular.add('$yol:$satir');
    }
  }
  return bulgular;
}

void main() {
  test('FAB VARKEN bos durumda IKINCI dugme YOK', () {
    final ihlaller = <String>[];
    var taranan = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      taranan++;
      ihlaller.addAll(ciftDugmeler(f.readAsStringSync(), f.path));
    }
    expect(taranan, greaterThan(200), reason: 'tarama gercekten kosmali');
    expect(ihlaller, isEmpty, reason: 'cift dugme: ${ihlaller.join(", ")}');
  });

  group('DEDEKTOR', () {
    test('FAB + BosDurum.onEylem YAKALANIR', () {
      const k = '''
        floatingActionButton: FloatingActionButton.extended(),
        body: BosDurum(ikon: Icons.x, baslik: 'y', onEylem: () {}),
      ''';
      expect(ciftDugmeler(k, 'x.dart'), hasLength(1));
    });

    test('FAB YOKKEN bos durum dugmesi SERBEST', () {
      // FAB'i olmayan bir ekranda tek cagri dugmesi dogru davranistir.
      const k = "body: BosDurum(ikon: Icons.x, baslik: 'y', onEylem: () {})";
      expect(ciftDugmeler(k, 'x.dart'), isEmpty);
    });

    test('FAB + dugmesiz BosDurum TEMIZ', () {
      const k = '''
        floatingActionButton: FloatingActionButton.extended(),
        body: BosDurum(ikon: Icons.x, baslik: 'y', aciklama: 'z'),
      ''';
      expect(ciftDugmeler(k, 'x.dart'), isEmpty);
    });
  });
}
