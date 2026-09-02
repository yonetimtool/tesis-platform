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
///   3. giriş ekranı gerçekten notun anlattığı alanı çizsin (P205'ten
///      beri: e-posta VEYA telefon kabul eden TEK alan).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notlar = '../docs/app-store/review-notes.md';
const _tohum = '../backend/scripts/demo_tenant.py';
const _giris = 'lib/src/features/auth/presentation/login_screen.dart';

/// (P154) Mobil yuzeyi OLMAYAN demo hesabi. Girise uygun degildir ve bu
/// yuzden giris tablosunda yer almaz — ama notta ADI GECMELIDIR, yoksa
/// tohumlamanin actigi bir hesap belgesiz kalir.
const _denetciTel = '+905777777777';

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
    // Ve dogrusunu ACIKCA soylemeli. (P205) Ekran TEK ALANA dustu —
    // e-posta ARTIK KABUL EDILIYOR — ama denetciye hangi sutunun
    // olculmus oldugu soylenmeli, yoksa dogrulanmamis bir yolla
    // deneyip ret uretebilir.
    expect(n, contains('Demo hesapları için TELEFON kullanın'));
  });

  test('NOTTAKI telefonlar TOHUMLAMA betigiyle AYNI', () {
    // Belge ile veri ayrisirsa denetci var olmayan bir hesapla dener.
    final tohum = _oku(_tohum);
    final numaralar = RegExp(r'"(\+90\d{10})"')
        .allMatches(tohum)
        .map((m) => m.group(1)!)
        .toSet();
    // (P143) DORT -> BES: `guvenlik_amiri` hesabi eklendi. Rol enum'da
    // vardi ama PROD'DA TEK KULLANICISI YOKTU — yani hic denenmemisti.
    // (P154) BES -> ALTI: `denetci` hesabi eklendi.
    // (P193) ALTI -> YEDI: IKINCI YONETICI eklendi. Gerekce belgede
    // (§8): `POST /me/hesap-sil` tesisin SON yoneticisini 409 ile
    // reddediyor — dogru bir kural, ama denetci silmeyi tek yonetici
    // hesabiyla denerse CALISAN bir ozellik yuzunden ret alirdik.
    expect(numaralar.length, 7,
        reason: 'tohumlama betiginde yedi demo numarasi bekleniyor');

    final n = _oku(_notlar);
    for (final e164 in numaralar) {
      // GIRIS TABLOSUNDAKILER yerel bicimde yazilir (denetci onlari
      // uygulamaya oyle girer); denetci hesabi ise TABLODA DEGIL,
      // gerekcesiyle birlikte E.164 olarak aniliyor — asagidaki teste
      // bakin.
      expect(n, contains(e164 == _denetciTel ? e164 : _yerel(e164)),
          reason: '$e164 denetim notlarinda hic gecmiyor');
    }
  });

  test('DENETCI hesabi giris tablosunda YOK ama notta ACIKLANMIS', () {
    // Kilitli kural 5: "Denetcinin mobil yuzeyi yoktur." Hesabi giris
    // tablosuna koymak, App Store denetcisine mobilde bos gorunen bir
    // ekran actirir ve uygulamayi bozuk gosterirdi. Kaldirmak da olmaz:
    // hesap yonetim paneli icin GERCEKTEN aciliyor.
    final n = _oku(_notlar);
    expect(n, contains(_denetciTel),
        reason: 'denetci hesabi notta hic anilmiyor');
    // Tabloda OLMADIGI da yazili olmali — yoksa bir sonraki tur onu
    // "eksik" sanip tabloya ekler.
    expect(n, contains('`denetci` rolü YOK'),
        reason: 'denetcinin tabloda neden olmadigi yazilmamis');
    // Ve tabloya SIZMAMIS olmali (satirlar `| Rol | 0... |` bicimindedir).
    expect(n, isNot(contains('| ${_yerel(_denetciTel)} |')),
        reason: 'denetci hesabi giris tablosuna girmis');
  });

  test('NOTTAKI e-postalar da tohumlama betigiyle AYNI', () {
    // E-postalar artik GIRIS icin degil, kaydi tanimak icin listeli —
    // ama yine de gercek olmali.
    final tohum = _oku(_tohum);
    final postalar = RegExp(r'"([a-z]+@demo\.yonetio\.site)"')
        .allMatches(tohum)
        .map((m) => m.group(1)!)
        .toSet();
    // (P143) Bes hesap: dort rol + guvenlik amiri. (P154) Altinci:
    // denetci — o TABLODA degil, gerekce paragrafinda geciyor.
    expect(postalar.length, 6);
    final n = _oku(_notlar);
    for (final e in postalar) {
      expect(n, contains(e), reason: '$e denetim notlarinda yok');
    }
  });

  test('GIRIS EKRANI gercekten TEK KIMLIK alani ciziyor', () {
    // Notun dayandigi gercek. (P205) Ekran telefon-yalniz olmaktan
    // cikti: tek alan hem e-postayi hem telefonu kabul ediyor. Alan
    // yeniden bolunurse ya da telefona geri donerse bu test duser ve
    // NOTUN da guncellenmesi gerektigini hatirlatir.
    final g = _oku(_giris);
    expect(g, contains('girisKimlik'));
    expect(g, contains('TextInputType.emailAddress'));
    // Telefon-yalniz alanin izleri geri gelmemeli. ("Cep telefonu"
    // etiketi ve rakam disini yutan bicimlendirici; ikincisi ADIYLA
    // aranmaz cunku ekranin aciklama yorumunda NEDEN kaldirildigi
    // yaziyor ve yazmaya da devam etmeli.)
    expect(g, isNot(contains('ortakCepTelefonu')));
    expect(g, isNot(contains('inputFormatters')));
  });
}
