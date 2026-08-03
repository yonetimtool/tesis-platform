/// (P123) TELEFON GİRİŞİ — TEK biçimlendirici, TEK kural, HER alan.
///
/// Bugüne kadar altı ayrı telefon alanı vardı ve altısı da **ham metin**
/// kabul ediyordu: kullanıcı `0543 199 29 04` da yazabiliyordu
/// `+905431992904` de `543-199-29-04` de. Sunucudaki `normalize_phone`
/// hepsini kabul ettiği için hiçbiri "hata" vermiyordu — ama:
///   * ekranda okunması zor (gruplanmamış 11 hane),
///   * yanlışlıkla 12. haneyi yazmak **sessizce** geçiyor ve sunucudan
///     anlaşılmaz bir 422 dönüyordu,
///   * geçersiz bir operatör ön eki (`0234…`) ancak KAYDETTİKTEN sonra
///     fark ediliyordu.
///
/// TEL BİÇİMİ **DEĞİŞMEDİ**: sunucuya giden değer yine `normalize_phone`in
/// kabul ettiği biçimdedir ([telefonNormalle] E.164 üretir). Değişen tek
/// şey kullanıcının gördüğü ve yazdığı şey.
///
/// **NEDEN AYRI BİR PAKET DEĞİL** (`mask_text_input_formatter` vb.):
/// ihtiyacımız tek bir ülkenin tek bir kalıbı ve iki kural (uzunluk +
/// operatör ön eki). Genel bir maske paketi, yapıştırma ve geri silme
/// davranışını kendi kurallarıyla getirir ve TR ön ek doğrulaması yine
/// bize kalırdı — bağımlılık yüzeyi kazanç sağlamıyor.
library;

import 'package:flutter/services.dart';

/// TR cep numarası: `5` ile başlayan 10 hane (baştaki `0` hariç).
const kTelefonHaneSayisi = 10;

/// Ekranda görünen gruplama: `0` + `543` `199` `29` `04`.
const _gruplar = <int>[3, 3, 2, 2];

/// Türkiye mobil operatör ön ekleri (ilk üç hane).
///
/// LİSTE **KAPALI DEĞİL**: BTK yeni blok tahsis edebilir. Bu yüzden kural
/// "listede yoksa reddet" değil, **"5 ile başlamıyorsa reddet"**tir; liste
/// yalnızca bilinen bir yazım hatasını (`0543` yerine `0534`) daha erken
/// yakalamak için değil, **sabit hattı** ayırmak için var: `0212…` bir cep
/// numarası değildir ve SMS gitmez. Sabit hat gerektiğinde bu alan
/// kullanılmaz.
bool telefonOnEkiGecerli(String haneler) {
  if (haneler.isEmpty) return true; // henüz yazılıyor
  return haneler.startsWith('5');
}

/// Ham girdiden YALNIZ haneleri çıkarır ve TR yerel biçimine indirger.
///
/// `+90`, `0090`, `90` ve baştaki `0` **soyulur**: kullanıcı numarayı
/// nereden yapıştırırsa yapıştırsın aynı 10 haneye iner. Yapıştırmanın
/// çalışması şart — insanlar numarayı rehberden kopyalar ve oradan
/// `+90 543 199 29 04` gelir.
String telefonHaneleri(String ham) {
  var s = ham.replaceAll(RegExp(r'\D'), '');
  if (s.startsWith('0090')) {
    s = s.substring(4);
  } else if (s.startsWith('90') && s.length > kTelefonHaneSayisi) {
    // `90` YALNIZ fazladan hane varken ülke kodu sayılır: `9053…` diye
    // başlayan bir numara yoktur ama `905431992904` (12 hane) vardır.
    s = s.substring(2);
  }
  if (s.startsWith('0')) s = s.substring(1);
  if (s.length > kTelefonHaneSayisi) s = s.substring(0, kTelefonHaneSayisi);
  return s;
}

/// Haneleri `0543 199 29 04` biçiminde gösterir (eksikse kısmi).
String telefonBicimle(String haneler) {
  if (haneler.isEmpty) return '';
  final b = StringBuffer('0');
  var i = 0;
  for (final uzunluk in _gruplar) {
    if (i >= haneler.length) break;
    final son = (i + uzunluk).clamp(0, haneler.length);
    if (i > 0) b.write(' ');
    b.write(haneler.substring(i, son));
    i = son;
  }
  return b.toString();
}

/// Sunucuya gidecek değer — E.164 (`+905431992904`).
///
/// Sunucu `0543…` biçimini de kabul eder; yine de **normalleştirilmiş**
/// gönderilir: aynı numaranın iki farklı yazımla iki kayıt üretmesi, telefon
/// GLOBAL BENZERSİZ olduğu için bir çakışma hatasına dönüşürdü.
String telefonNormalle(String ham) {
  final h = telefonHaneleri(ham);
  return h.isEmpty ? '' : '+90$h';
}

/// Girdi biçimlendirici: yazarken gruplar, rakam dışını yutar, uzunluğu
/// **sert** sınırlar.
class TelefonBicimlendirici extends TextInputFormatter {
  const TelefonBicimlendirici();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    final haneler = telefonHaneleri(yeni.text);
    final metin = telefonBicimle(haneler);

    // FAZLA HANE YAZILAMAZ: 10 hane doluyken yeni rakam metni DEĞİŞTİRMEZ.
    // İmleci de eski yerinde bırakmak gerekir, aksi halde her tuşta imleç
    // sona sıçrar ve ortadan düzeltme yapmak imkânsızlaşır.
    if (metin == eski.text) return eski;

    // İMLEÇ: kullanıcı sona yazıyorsa sonda kalsın. Ortadan düzeltmede
    // hane sayısını koruyarak yeniden konumlandırmak gerekir; basit ve
    // öngörülebilir olan, imleci girilen hane sayısına göre hesaplamaktır.
    final imlecHane = telefonHaneleri(
      yeni.text.substring(0, yeni.selection.end.clamp(0, yeni.text.length)),
    ).length;
    return TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(
        offset: _haneninEkranKonumu(metin, imlecHane),
      ),
    );
  }

  /// [n] hane girildiğinde imlecin biçimli metindeki konumu.
  ///
  /// **n'inci hanenin ARDI** döner, n'inci hanenin kendisi değil: imleç
  /// yazılan rakamdan SONRA durur. İlk yazımda bu bir eksikti ve her
  /// tuşta imleç bir karakter geride kalıyordu — kullanıcı 5 hane yazınca
  /// altıncıyı bir önceki hanenin soluna yazardı. Test yakaladı.
  static int _haneninEkranKonumu(String metin, int n) {
    if (metin.isEmpty) return 0;
    if (n <= 0) return 1; // baştaki `0`ın ardı
    final rakam = RegExp(r'\d');
    var sayac = 0;
    // i=1'den başlar: indeks 0'daki `0` bir HANE değil, biçim ekidir.
    for (var i = 1; i < metin.length; i++) {
      if (rakam.hasMatch(metin[i])) {
        sayac++;
        if (sayac == n) return i + 1;
      }
    }
    return metin.length;
  }
}

/// Doğrulama sonucu — METİN DEĞİL KİMLİK (README §15: domain dil bilmez).
enum TelefonHatasi {
  /// Alan zorunlu ama boş.
  bos,

  /// 10 haneden az.
  eksik,

  /// `5` ile başlamıyor (sabit hat / hatalı ön ek).
  gecersizOnEk,
}

/// [ham] için hata kimliği; `null` = geçerli.
///
/// [zorunlu] false ise boş değer geçerlidir (profil telefonu gibi
/// isteğe bağlı alanlar).
TelefonHatasi? telefonHatasi(String ham, {bool zorunlu = true}) {
  final h = telefonHaneleri(ham);
  if (h.isEmpty) return zorunlu ? TelefonHatasi.bos : null;
  if (!telefonOnEkiGecerli(h)) return TelefonHatasi.gecersizOnEk;
  if (h.length < kTelefonHaneSayisi) return TelefonHatasi.eksik;
  return null;
}

