/// TUR 33 — CIPLAK `GestureDetector` KAYNAK DENETIMI.
///
/// Klavye surusu (`klavyeSurusu`) CIZILEN ekrani tarar; ama bazi
/// dokunulabilir ogeler yalniz belirli VERIYLE cizilir — talep/duyuru/etkinlik
/// fotograf kucuk resimleri, yukleme yuvasinin "yeniden dene" kaplamasi,
/// kamera oynaticinin dokunma yuzeyi. Test kosumlarinda fotograf olmadigi
/// icin surus bu kod yollarina HIC ugramaz; tur 33'te altisi da ancak
/// KAYNAK taramasiyla bulundu.
///
/// Kural: `GestureDetector` kendi `Focus`unu KURMAZ. Yalniz dokunmayla
/// calisir — harici klavye, anahtar erisimi (switch access) ve masaustu
/// (Windows/macOS/web hedefleri) icin oge ERISILEMEZDIR. `InkWell`,
/// `IconButton`, `TextButton` ve `FocusableActionDetector` odaklanabilir.
///
/// KACINILMAZ istisna (pan/scale/surukleme) gerekirse: oge `Focus` ya da
/// `FocusableActionDetector` ile SARILMALI ve buraya gerekcesiyle yazilmali.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/src icinde ciplak GestureDetector yok (klavyeyle ulasilamaz)', () {
    final bulunan = <String>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final satirlar = e.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        if (satirlar[i].contains('GestureDetector(')) {
          bulunan.add('${e.path}:${i + 1}');
        }
      }
    }
    expect(bulunan, isEmpty,
        reason: 'Ciplak GestureDetector KLAVYEYLE ULASILAMAZ. InkWell / '
            'IconButton / FocusableActionDetector kullanin, ya da ogeyi '
            'Focus ile sarip bu testin dokumanina gerekce ekleyin:\n'
            '${bulunan.join("\n")}');
  });
}
