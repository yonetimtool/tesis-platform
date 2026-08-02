/// P116 — YER TUTUCU SÜPÜRMESİ: denetimi düşüren şeyler.
///
/// App Store denetiminde en sık ret sebeplerinden biri "özellik
/// tamamlanmamış" bulgusudur: dokunulduğunda hiçbir şey yapmayan düğme,
/// "Yakında" yazan bir menü satırı, açıklamasız boş ekran. Bu dosya
/// üçünü de **ölçer** ve sayıyı sıfırda kilitler.
///
/// ÖLÇÜM (2026-08-02): rotasız kart **0**, "Yakında" işaretli menü
/// girişi **0**. Yani `ortakYakinda`/`ortakBolumYakinda` metinleri
/// **erişilemez** dallarda duruyor — savunma olarak kalıyorlar (rota
/// eklenmeyi unutulan bir kart sessiz bir ölü düğme yerine dürüst bir
/// mesaj gösterir), ama bugün hiçbiri çizilmiyor.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bir kurucu çağrısının parantezleri arasındaki gövdeyi döndürür.
List<String> _cagriGovdeleri(String kaynak, String tur) {
  final govdeler = <String>[];
  final kalip = RegExp('\\b$tur\\s*\\(');
  for (final m in kalip.allMatches(kaynak)) {
    var derinlik = 1;
    var j = m.end;
    while (derinlik > 0 && j < kaynak.length) {
      if (kaynak[j] == '(') derinlik++;
      if (kaynak[j] == ')') derinlik--;
      j++;
    }
    govdeler.add(kaynak.substring(m.end, j - 1));
  }
  return govdeler;
}

Iterable<File> _dartDosyalari() sync* {
  for (final e in Directory('lib/src').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

void main() {
  test('ROTASIZ KART YOK — dokununca hicbir sey yapmayan modul kalmadi', () {
    // `rota` null olan bir kart, kullaniciya acilmayan bir kapi
    // gostermektir. Ana ekranlarda bunun icin bir "yakinda" dali var ama
    // o dal BUGUN erisilemez olmali.
    final rotasiz = <String>[];
    for (final f in _dartDosyalari()) {
      final kaynak = f.readAsStringSync();
      // TUR ADLARI OLCULEREK secildi ve KAPSAM iki kez daraltildi:
      //   1. Ilk yazimda uydurma iki ad ('HomeKisayol', 'ModulKarti')
      //      taraniyordu; mutasyon denetimi yakaladi — tarama HICBIR SEY
      //      olcmuyordu ve yesil yaniltiyordu.
      //   2. Sonra `HareketSatiri` de eklendi ve kirmizi verdi; oysa o
      //      "Son Hareketler" GUNLUK SATIRIDIR, gezinme karti degil —
      //      rotasi olmamasi DOGRUDUR. Kapsam, dokununca bir yere
      //      GITMESI beklenen iki kartla sinirli.
      for (final tur in ['HizliErisimKart', 'OzetKutusu']) {
        for (final govde in _cagriGovdeleri(kaynak, tur)) {
          // Kurucu TANIMI (`this.rota` iceren) atlanir.
          if (govde.contains('this.')) continue;
          if (!govde.contains('rota:')) rotasiz.add('${f.path} ($tur)');
        }
      }
    }
    expect(rotasiz, isEmpty,
        reason: 'Rotasi olmayan kart(lar): ${rotasiz.join(", ")}');
  });

  test('"YAKINDA" isaretli menu girisi YOK', () {
    // `comingSoon: true` bir menu satirini pasif "Yakında" olarak cizer.
    // Denetim tesisinde gorunen boyle bir satir, "urun yarim" izlenimi
    // verir ve tek basina ret sebebi olabilir.
    final yakinda = <String>[];
    for (final f in _dartDosyalari()) {
      final kaynak = f.readAsStringSync();
      for (final govde in _cagriGovdeleri(kaynak, 'BildirGiris')) {
        if (govde.contains('this.')) continue; // kurucu tanimi
        if (govde.contains('comingSoon: true') || !govde.contains('route:')) {
          yakinda.add(f.path);
        }
      }
    }
    expect(yakinda, isEmpty,
        reason: '"Yakında" ya da rotasiz menu girisi: ${yakinda.join(", ")}');
  });

  test('OLU DUGME YOK — bos govdeli onPressed/onTap kalmadi', () {
    // `onPressed: () {}` dokunulabilir ama HICBIR SEY yapmayan bir
    // dugmedir; `onPressed: null` ise BILINCLI pasif haldir ve
    // taranmaz (yukleme sirasinda kilitleme deseni).
    final olu = <String>[];
    final kalip = RegExp(r'on(Pressed|Tap|Changed)\s*:\s*\(\s*[^)]*\)\s*\{\s*\}');
    for (final f in _dartDosyalari()) {
      final satirlar = f.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final kod = satirlar[i].split('//').first;
        if (kalip.hasMatch(kod)) olu.add('${f.path}:${i + 1}');
      }
    }
    expect(olu, isEmpty, reason: 'Bos govdeli dokunma: ${olu.join(", ")}');
  });
}
