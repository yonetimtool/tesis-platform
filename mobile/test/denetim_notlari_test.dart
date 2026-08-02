/// DENETİM NOTLARI ile GERÇEĞİN ÖRTÜŞMESİ (App Store).
///
/// TestFlight Build 1'de not, denetçiye **"e-posta + tesis kodu ile
/// giriş"** diyordu — ama mobil giriş ekranında öyle bir alan **yok**
/// (telefon + parola). Denetçi giriş yapamazdı; bu tek başına kesin ret
/// sebebidir ve kodun hiçbir testi bunu göremezdi, çünkü hata **belgede**
/// idi.
///
/// Bu dosya belgeyi bir SÖZLEŞME gibi ele alır ve üç şeyi bağlar:
///   1. not, mobilde olmayan bir giriş yolu VAAT ETMESİN,
///   2. nottaki telefon numaraları, tohumlama betiğinin GERÇEKTEN
///      yazdığı numaralarla AYNI olsun,
///   3. giriş ekranı gerçekten TELEFON alanı çizsin.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notlar = '../docs/app-store/review-notes.md';
const _tohum = '../backend/scripts/demo_tenant.py';
const _giris = 'lib/src/features/auth/presentation/login_screen.dart';

String _oku(String yol) => File(yol).readAsStringSync();

/// `+905000000101` → `05000000101` (kullanıcının yazdığı biçim).
String _yerel(String e164) => '0${e164.substring(3)}';

void main() {
  test('NOT, mobilde OLMAYAN bir giris yolu vaat ETMIYOR', () {
    // Mobil giris ekraninda tesis kodu alani YOKTUR; "e-posta + tesis
    // kodu ile giris yapin" demek denetciyi cikmaza sokar.
    final n = _oku(_notlar);
    for (final yasak in [
      'e-posta + tesis kodu kullanılabilir',
      'demo\nhesapları e-posta ile girer',
      'hesapları e-posta ile girer',
    ]) {
      expect(n.contains(yasak), isFalse,
          reason: 'not hala e-posta giris vaat ediyor: "$yasak"');
    }
    // Ve dogrusunu ACIKCA soylemeli.
    expect(n, contains('GİRİŞ TELEFONLADIR'));
  });

  test('NOTTAKI telefonlar TOHUMLAMA betigiyle AYNI', () {
    // Belge ile veri ayrisirsa denetci var olmayan bir hesapla dener.
    final tohum = _oku(_tohum);
    final numaralar = RegExp(r'"(\+90\d{10})"')
        .allMatches(tohum)
        .map((m) => m.group(1)!)
        .toSet();
    expect(numaralar.length, 4,
        reason: 'tohumlama betiginde dort demo numarasi bekleniyor');

    final n = _oku(_notlar);
    for (final e164 in numaralar) {
      expect(n, contains(_yerel(e164)),
          reason: '$e164 (yerel: ${_yerel(e164)}) denetim notlarinda yok');
    }
  });

  test('NOTTAKI e-postalar da tohumlama betigiyle AYNI', () {
    // E-postalar artik GIRIS icin degil, kaydi tanimak icin listeli —
    // ama yine de gercek olmali.
    final tohum = _oku(_tohum);
    final postalar = RegExp(r'"([a-z]+@demo\.yonetio\.site)"')
        .allMatches(tohum)
        .map((m) => m.group(1)!)
        .toSet();
    expect(postalar.length, 4);
    final n = _oku(_notlar);
    for (final e in postalar) {
      expect(n, contains(e), reason: '$e denetim notlarinda yok');
    }
  });

  test('GIRIS EKRANI gercekten TELEFON alani ciziyor', () {
    // Notun dayandigi gercek. Ekran bir gun e-posta girisine cevrilirse
    // bu test duser ve NOTUN da guncellenmesi gerektigini hatirlatir.
    final g = _oku(_giris);
    expect(g, contains('TextInputType.phone'));
    expect(g, contains('ortakCepTelefonu'));
  });
}
