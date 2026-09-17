/// (P239 §1) IZGARA KART ADI KELIME ORTASINDAN BOLUNMEZ — 7 DILDE.
///
/// =========================================================================
/// P229 KILIDI BUNU NEDEN YAKALAMADI
/// =========================================================================
/// `dugme_metni_tasmasi_test` (P229 §1) iki sebeple goremezdi:
///   1. DUGME etiketlerini tariyor — izgara KART adlari kapsaminda degil.
///   2. SATIR SAYISI olcuyor. Kart adi zaten IKI SATIRA sarabilir (tasarim
///      boyle); "Görüntülem / e İzni" de iki satirdir. Yani sayim dogru,
///      BOLUNME YERI yanlis — olculmeyen sey tam olarak buydu.
///
/// Bu kilit BOLUNME YERINI olcer: bir satir sonu, iki yaninda da BOSLUK
/// OLMAYAN bir yerde olusuyorsa kelime ortasindan bolunmustur.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/kelime_bolunmez.dart';

/// (P229 kalibrasyonu) `flutter_test` fontu her glifi KARE EM cizer:
/// genislik = karakter x fontSize. Gercek fontlarda Latin/Kiril ortalamasi
/// ~0.52 em. Kart metin alani 4 sutunlu izgarada 320dp'de ~68dp; ayni esigi
/// test fontuyla yakalamak icin 68 / 0.52 ~= 131 kullanilir.
const double kKartMetinGenisligi = 131;

/// Izgara kartlarinin adlari `modul...` onekiyle duruyor.
const String kOnek = 'modul';

/// Bir satir sonu KELIME ORTASINDA mi?
///
/// `TextPainter`in satirlarini karakter karakter cikarir: her karakterin
/// caret'inin DIKEY konumu satiri belirler. Satir degisiminde onceki ve
/// sonraki karakterlerin ikisi de bosluk DEGILSE, bolunme kelime
/// ortasindadir.
List<String> kelimeBolunmeleri(String metin, double punto, double genislik) {
  final tp = TextPainter(
    text: TextSpan(text: metin, style: TextStyle(fontSize: punto)),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: genislik);

  final bulgular = <String>[];
  double? oncekiY;
  for (var i = 0; i < metin.length; i++) {
    final y = tp.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
    if (oncekiY != null && y != oncekiY && i > 0) {
      final onceki = metin[i - 1];
      final simdiki = metin[i];
      // TIRE/EGIK CIZGIDEN SONRA BOLUNME MESRUDUR: "Site-" / "Budget" bir
      // HECE bolunmesi degil, Unicode'un zaten tanidigi bir satir sonu
      // firsatidir. Ilk yazim bunu ihlal sayiyordu ve DOGRU bir tipografiyi
      // kusur gibi gosteriyordu (Almanca bilesik adlarin hepsi boyle).
      if (onceki.trim().isNotEmpty &&
          simdiki.trim().isNotEmpty &&
          !const {'-', '/', '‐', '–', '—'}.contains(onceki)) {
        bulgular.add('${metin.substring(0, i)} | ${metin.substring(i)}');
      }
    }
    oncekiY = y;
  }
  tp.dispose();
  return bulgular;
}

Map<String, String> _arb(String dil) {
  final f = File('lib/l10n/app_$dil.arb');
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in j.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

void main() {
  const diller = ['tr', 'en', 'de', 'fr', 'es', 'ru', 'ar'];

  test('KART ADLARI kelime ortasindan BOLUNMEZ (7 dil, 320dp)', () {
    final ihlaller = <String>[];
    var taranan = 0;
    for (final dil in diller) {
      for (final e in _arb(dil).entries) {
        if (!e.key.startsWith(kOnek)) continue;
        taranan++;
        // KARTIN GERCEKTEN KULLANACAGI PUNTO ile olculur.
        //
        // Ilk yazim sabit 14 puntoda olcuyordu ve duzeltmeden SONRA da
        // kirmizi kalirdi — cunku kart 14'te cizmiyor. Olculmesi gereken
        // sey uretim algoritmasinin SECTIGI puntodur; kilit boylece
        // "metin kisa mi" degil "kart dogru mu cizyor" sorusunu sorar.
        final punto = kartBaslikPuntosu(e.value, kKartMetinGenisligi);
        if (punto == null) {
          // (c) hicbir puntoda sigmiyor -> kart TEK SATIR cizer, sarma
          // olmaz, dolayisiyla bolunme de olmaz.
          continue;
        }
        final b = kelimeBolunmeleri(e.value, punto, kKartMetinGenisligi);
        for (final x in b) {
          ihlaller.add('$dil/${e.key} @${punto}pt: $x');
        }
      }
    }
    expect(taranan, greaterThan(100), reason: 'tarama gercekten kosmali');
    expect(ihlaller, isEmpty,
        reason: 'kelime ortasindan bolunme:\n${ihlaller.join("\n")}');
  });

  test('BUYUK YAZI TIPI (x1.6) ile de bolunme YOK', () {
    // Erisilebilirlik ayari puntoyu buyutur; taban puntoyu kucultmek
    // yetmez, olcek HESABA girmeli. Girmezse en uzun kelime yine tasar.
    const olcek = TextScaler.linear(1.6);
    final ihlaller = <String>[];
    for (final dil in diller) {
      for (final e in _arb(dil).entries) {
        if (!e.key.startsWith(kOnek)) continue;
        final punto = kartBaslikPuntosu(
          e.value,
          kKartMetinGenisligi,
          olcek: olcek,
        );
        if (punto == null) continue;
        final b = kelimeBolunmeleri(
          e.value,
          olcek.scale(punto),
          kKartMetinGenisligi,
        );
        for (final x in b) {
          ihlaller.add('$dil/${e.key} @${punto}pt x1.6: $x');
        }
      }
    }
    expect(ihlaller, isEmpty, reason: ihlaller.join('\n'));
  });

  test('EN KUCUK PUNTODA DA SIGMAYAN ad TEK SATIRA duser (null)', () {
    // (c) maddesi: iki satira BOLMEK yerine sondan kesilir. Uretim kodu
    // bunu `null` ile bildirir; kart `maxLines: 1` cizer.
    expect(kartBaslikPuntosu('Beschwerdeverwaltungsuebersicht', 40), isNull);
  });

  test('BOLUNMEZ PARCALAR tire ve boslukta ayrilir', () {
    expect(bolunmezParcalar('Site-Budget'), ['Site-', 'Budget']);
    expect(bolunmezParcalar('Görüntüleme İzni'), ['Görüntüleme', 'İzni']);
    expect(bolunmezParcalar('Beschwerde / Vorschlag'),
        ['Beschwerde', '/', 'Vorschlag']);
  });

  group('DEDEKTOR — olcum gercekten calisiyor', () {
    test('SIGMAYAN TEK KELIME bolunmeyi YAKALAR', () {
      // Tek bir uzun kelime: Flutter satir sonunu kelime ICINDE acar.
      expect(kelimeBolunmeleri('Goruntulemeizni', 14, 60), isNotEmpty);
    });

    test('BOSLUKTA SARAN metin TEMIZ', () {
      expect(kelimeBolunmeleri('Ab Cd', 14, 40), isEmpty);
    });

    test('TEK SATIRA SIGAN metin TEMIZ', () {
      expect(kelimeBolunmeleri('Ab', 14, 200), isEmpty);
    });
  });
}
