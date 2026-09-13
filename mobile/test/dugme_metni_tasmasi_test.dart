import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// (P229 §1) DUGME METNI TASMA KILIDI — 7 DILDE.
///
/// =========================================================================
/// NE OLCULDU (once), NE KILITLENIYOR (simdi)
/// =========================================================================
/// Bildirilen kusur "sigmayan kelimeler alt satira kayiyor" idi. Bu Flutter'da
/// ISTISNA URETMEZ — metin sessizce sarar. Yani mevcut `small_screen_overflow_
/// test`in kullandigi `takeException()` yontemi bu kusuru ASLA goremezdi;
/// nitekim ana ekranlar 7 dilde de istisnasiz geciyordu. Bu yuzden kilit
/// SARMA SAYISINI olcuyor.
///
/// Kok neden Almanca bilesik isimlerdi: `Benachrichtigungseinstellungen` gibi
/// 30 karakterlik BOLUNEMEZ kelimeler ve `Speichern und Bewohner
/// benachrichtigen` gibi uc kelimelik eylem etiketleri. Turkce esdegerleri
/// kisa oldugu icin kusur TR'de gorunmuyordu.
///
/// =========================================================================
/// GENISLIK NEDEN 446 — KALIBRASYON
/// =========================================================================
/// `flutter_test` varsayilan fontu HER GLIFI KARE EM cizer: genislik =
/// karakter sayisi x fontSize. Gercek fontlarda Latin/Kiril ortalamasi
/// ~0.52 em'dir. 320dp ekranda tam genislikli bir dugmenin metin alani
/// 232dp; test fontuyla ayni esigi yakalamak icin 232 / 0.52 ~= 446 kullanilir.
///
/// KALIBRASYON DOGRULANDI: ayni tarama sistemdeki gercek DejaVuSans ile
/// `FontLoader` uzerinden de kosuldu; iki liste 7'ye 6 ortusuyor, fark
/// yalnizca esik uzerindeki sinir vakalari. Sistem fontuna BAGLANMADI cunku
/// `/usr/share/fonts` her ortamda yok — kilit tasinabilir kalmali.
const double kDugmeGenisligi = 446;

/// (P229 §1) SARMASI KABUL EDILEN ETIKETLER.
///
/// Bunlar dugme DEGIL, icinde bagalanti bulunan CUMLELERDIR ("Zaten
/// hesabiniz var mi? Giris yapin"). Iki satira sarmalari dogru davranistir;
/// kisaltmak cumleyi bozardi. Listeye yeni bir sey eklemek, "bu bir cumle"
/// demektir — eylem dugmesi ekleyen biri once bunu okumak zorunda kalir.
const kSarmasiSerbest = {'kayitGirisLinki', 'girisKayitBaglantisi'};

void main() {
  test('(P229 §1) dugme etiketleri 7 dilde de TEK SATIRA sigar', () {
    final anahtarlar = File('test/veri/dugme_etiketleri.txt')
        .readAsLinesSync()
        .where((e) => e.trim().isNotEmpty && !e.startsWith('#'))
        .toSet();
    expect(anahtarlar.length, greaterThan(60),
        reason: 'etiket listesi bosalmis — tarama anlamsizlasir');

    final diller = <String, Map<String, String>>{};
    for (final d in ['tr', 'de', 'ru', 'fr', 'es', 'en', 'ar']) {
      final j = jsonDecode(File('lib/l10n/app_$d.arb').readAsStringSync())
          as Map<String, dynamic>;
      diller[d] = {
        for (final e in j.entries)
          if (!e.key.startsWith('@') && e.value is String)
            e.key: e.value as String,
      };
    }

    // ICU cogul kaynagi TUM dallari icerir; ekranda yalniz BIRI cizilir.
    // Ham metni olcmek Arapca'da 6 dalli bir kaynagi 130 karakter sanardi.
    String isle(String s) {
      final m =
          RegExp(r'\{\w+,\s*plural,(.*)\}\s*$', dotAll: true).firstMatch(s);
      if (m != null) {
        final o = RegExp(r'other\s*\{([^{}]*)\}').firstMatch(m.group(1)!);
        if (o != null) s = o.group(1)!;
      }
      return s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (_) => 'Xxxxxx');
    }

    const stil = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    int satirSayisi(String metin) {
      final tp = TextPainter(
        text: TextSpan(text: metin, style: stil),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: kDugmeGenisligi);
      return tp.computeLineMetrics().length;
    }

    final tasan = <String>[];
    for (final k in anahtarlar) {
      if (kSarmasiSerbest.contains(k)) continue;
      if (!diller['tr']!.containsKey(k)) continue;
      for (final d in diller.keys) {
        final v = isle(diller[d]![k] ?? '');
        if (v.isEmpty) continue;
        final n = satirSayisi(v);
        if (n > 1) tasan.add('$k [$d] $n satir: "$v"');
      }
    }
    expect(tasan, isEmpty,
        reason: '320dp ekranda tam genislikli dugmede SARIYOR:\n'
            '${tasan.join('\n')}\n\n'
            'Cozum sirasi (P229 §1): (1) cevirisini KISALT — en ucuzu ve '
            'dokunma hedefine dokunmaz; (2) cumle ise kSarmasiSerbest\'e '
            'gerekcesiyle ekle; (3) ikisi de olmuyorsa duzeni degistir.');
  });

  test('(P229 §1) izgara karti basliklari IKI SATIRA sigar', () {
    // =====================================================================
    // NEDEN AYRI ESIK
    // =====================================================================
    // Izgara karti `AutoSizeText(maxLines: 2, minFontSize: 8)` kullanir:
    // sigmayan baslik TASMAZ, KUCULUR. Kilit bu yuzden TASARIM PUNTOSUNU
    // (12sp) degil TABANI (8sp) olcer.
    //
    // ILK YAZIMDA 12sp olculdu ve TURKCE bile dustu ("Aidat Tahsilat
    // Orani"): o esik tasarimin KENDISINI hatali ilan ediyordu, cunku
    // kuculme zaten beklenen davranis. Gercek kusur ancak 8sp'de de
    // sigmayinca baslar — orada AutoSizeText'in yapabilecegi kalmaz ve
    // baslik UC NOKTAYLA KESILIR.
    //
    // 320dp ekranda 4 sutunlu izgarada hucre ~72dp, yatay dolgu 6+6 ->
    // metin alani ~60dp. Kalibrasyon dugme testindekiyle ayni (0.52 em):
    // 60 / 0.52 ~= 115.
    final anahtarlar = File('test/veri/izgara_basliklari.txt')
        .readAsLinesSync()
        .where((e) => e.trim().isNotEmpty && !e.startsWith('#'))
        .toSet();
    expect(anahtarlar.length, greaterThan(25));

    final diller = <String, Map<String, String>>{};
    for (final d in ['tr', 'de', 'ru', 'fr', 'es', 'en', 'ar']) {
      final j = jsonDecode(File('lib/l10n/app_$d.arb').readAsStringSync())
          as Map<String, dynamic>;
      diller[d] = {
        for (final e in j.entries)
          if (!e.key.startsWith('@') && e.value is String)
            e.key: e.value as String,
      };
    }
    const stil = TextStyle(fontSize: 8, fontWeight: FontWeight.w600);
    final tasan = <String>[];
    for (final k in anahtarlar) {
      if (!diller['tr']!.containsKey(k)) continue;
      for (final d in diller.keys) {
        final v = diller[d]![k] ?? '';
        if (v.isEmpty) continue;
        final tp = TextPainter(
          text: TextSpan(text: v, style: stil),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 115);
        final n = tp.computeLineMetrics().length;
        if (n > 2) tasan.add('$k [$d] $n satir: "$v"');
      }
    }
    expect(tasan, isEmpty,
        reason: '4 sutunlu izgarada EN KUCUK PUNTODA (8sp) bile iki satira '
            'sigmiyor — AutoSizeText\'in yapabilecegi kalmaz, baslik UC '
            'NOKTAYLA KESILIR:\n${tasan.join('\n')}');
  });
}
