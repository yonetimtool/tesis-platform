/// (P243 §6c) BOS DURUM MESAJLARI REHBER OLMALI — MOBIL.
///
/// =========================================================================
/// OLCULEN SEY
/// =========================================================================
/// Brief: "Boş liste ekranlarında 'Kayıt yok' yerine ne yapması
/// gerektiğini söyleyen mesaj olsun. TÜM boş ekranları tara ve düzelt."
///
/// Tarama iki ayri kusur buldu:
///   1. `BosDurum` kullanan 9 yerin 2'si `aciklama` VERMIYORDU,
///   2. 9 ekran `BosDurum`u HIC kullanmiyordu: ortasinda tek satir
///      `Center(child: Text(l10n.xxxYok))` vardi. Bu, bilesenin
///      var olmasina ragmen kuralin uygulanmadigi yerdi ve yalnizca
///      `BosDurum`u taramak onlari GORMEZDI.
///
/// Bu yuzden kilit IKI SEYI birden olcer: her `BosDurum` bir aciklama
/// tasir VE bos-liste dalinda ciplak `Center(child: Text(...))` kalmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `BosDurum(` cagrilarinin govdesini (parantez sayarak) ayikla.
List<String> _bosDurumGovdeleri(String kaynak) {
  final govdeler = <String>[];
  for (final e in RegExp(r'\bBosDurum\(').allMatches(kaynak)) {
    var i = e.end;
    var derinlik = 1;
    while (i < kaynak.length && derinlik > 0) {
      if (kaynak[i] == '(') derinlik++;
      if (kaynak[i] == ')') derinlik--;
      i++;
    }
    govdeler.add(kaynak.substring(e.end, i));
  }
  return govdeler;
}

Iterable<File> _dartDosyalari(Directory kok) =>
    kok.listSync(recursive: true).whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    );

void main() {
  final kok = Directory('lib/src');

  test('HER BosDurum bir aciklama tasir', () {
    final suclular = <String>[];
    for (final f in _dartDosyalari(kok)) {
      // Bilesenin KENDI tanimi haric: orada `aciklama` bir alandir.
      if (f.path.endsWith('core/ui/bos_durum.dart')) continue;
      for (final govde in _bosDurumGovdeleri(f.readAsStringSync())) {
        if (!govde.contains('aciklama:')) {
          suclular.add('${f.path}: ${govde.trim().split('\n').first}');
        }
      }
    }
    expect(suclular, isEmpty);
  });

  test('BOS LISTE dalinda CIPLAK Center(child: Text(...)) kalmadi', () {
    // Hata ve yukleme dallari disarida: orada tek satirlik metin dogru
    // cizimdir. Aranan sey "...Yok" / "...Bos" adli bir sozluk
    // anahtarinin ciplak bir `Text` icinde gecmesi.
    final desen = RegExp(
      r'Center\(\s*child:\s*Text\(\s*l10n\.\w*(Yok|Bos)\b',
      caseSensitive: true,
    );
    final suclular = <String>[];
    for (final f in _dartDosyalari(kok)) {
      final kaynak = f.readAsStringSync();
      for (final e in desen.allMatches(kaynak)) {
        suclular.add('${f.path}: ${e.group(0)}');
      }
    }
    expect(suclular, isEmpty);
  });

  test('TARAMA GERCEKTEN CALISIYOR (kilit kendini olcer)', () {
    // Kilit, kirilmadigi surece gecerli sayilmaz. Sahte kaynak uzerinde:
    // ic ice parantezli bir cagri govdesi dogru ayiklaniyor mu?
    final govdeler = _bosDurumGovdeleri('''
      BosDurum(ikon: Icons.a, baslik: l10n.b)
      BosDurum(ikon: Icons.c, baslik: f(g(1)), aciklama: l10n.d)
    ''');
    expect(govdeler, hasLength(2));
    expect(govdeler.where((g) => !g.contains('aciklama:')), hasLength(1));
  });
}
