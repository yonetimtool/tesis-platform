/// (P233 §3) ÜLKE KODU TABLOSU — telefonun TEK kaynağı.
///
/// Panel ikizi: `admin-web/lib/ulke-telefon.ts`. İki dosya AYNI tabloyu
/// taşır; ayrışırlarsa yönetici panelde kaydettiği numarayı mobilde farklı
/// görür ya da biri kabul edip diğeri reddeder.
///
/// =========================================================================
/// NEDEN BİR TABLO, NEDEN "+90 SABİT" YETMEDİ
/// =========================================================================
/// P123'ten P233'e kadar telefon TR'ye SABİTLENMİŞTİ: [telefonNormalle]
/// her numaranın başına koşulsuz `+90` koyuyordu. Yabancı uyruklu bir
/// sakin ya da yurt dışındaki bir mal sahibi numarasını girdiğinde ekranda
/// hiçbir şey ters görünmüyor, ama saklanan değer BAŞKA BİR NUMARAYDI —
/// telefon GLOBAL BENZERSİZ anahtar olduğu için bu, ya başkasının
/// numarasıyla çakışma ya da erişilemez bir hesap demektir.
///
/// =========================================================================
/// UZUNLUK SINIRI NEDEN ARALIK, TEK SAYI DEĞİL
/// =========================================================================
/// Ülkelerin çoğunda cep numarası uzunluğu TEK değildir (IT 9-10, BG 8-9).
/// Maliyet SİMETRİK DEĞİL: aralık gereğinden GENİŞ olursa yalnızca bir
/// yazım hatasını yakalayamayız; gereğinden DAR olursa gerçek bir insan
/// kaydolamaz. Emin olmadığım yerde aralık GENİŞLETİLDİ.
///
/// LİSTE NEDEN BU: tam ITU listesi için 240 ülkenin aralığını UYDURMAM
/// gerekirdi ve uydurulmuş DAR bir aralık yukarıdaki asimetriye göre en
/// kötü sonucu verir. Liste = Türkiye + ürünün 7 dilinin konuşulduğu
/// ülkeler + komşular + sakin/çalışan olarak sık görülen ülkeler. Eksik
/// bir ülke, tabloya TEK SATIR eklenerek gelir.
library;

class Ulke {
  const Ulke({
    required this.kod,
    required this.arama,
    required this.enAz,
    required this.enCok,
    required this.bayrak,
    this.gruplar,
    this.mobilOnEk,
  });

  /// ISO 3166-1 alpha-2 — listenin anahtarı (saklanan değer DEĞİL).
  final String kod;

  /// Arama kodu, `+` HARİÇ (`"90"`).
  final String arama;

  /// Ulusal numaranın en az/en çok hane sayısı (ülke kodu hariç).
  final int enAz;
  final int enCok;

  /// Ekranda gruplama; null ise üçerli parçalanır.
  final List<int>? gruplar;

  /// Cep numarasının başlaması gereken hane (yalnız TR'de uygulanır).
  final String? mobilOnEk;

  final String bayrak;

  /// Seçenek etiketi: `TR +90`. Ülke ADI kullanılmadı — 50 ülke × 7 dil =
  /// 350 çeviri borcu, ve ISO kodu + arama kodu DİLDEN BAĞIMSIZ okunur.
  /// `+1`i paylaşan US/CA ile `+7`yi paylaşan RU/KZ yalnızca ISO koduyla
  /// ayrılır; arama kodu tek başına yeterli olmazdı.
  String get etiket => '$kod +$arama';
}

/// TR İLK SIRADA: kullanıcıların ezici çoğunluğu için doğru seçim.
const kUlkeler = <Ulke>[
  Ulke(kod: 'TR', arama: '90', enAz: 10, enCok: 10, gruplar: [3, 3, 2, 2], mobilOnEk: '5', bayrak: '\u{1F1F9}\u{1F1F7}'),
  Ulke(kod: 'DE', arama: '49', enAz: 9, enCok: 12, bayrak: '\u{1F1E9}\u{1F1EA}'),
  Ulke(kod: 'AT', arama: '43', enAz: 9, enCok: 13, bayrak: '\u{1F1E6}\u{1F1F9}'),
  Ulke(kod: 'CH', arama: '41', enAz: 9, enCok: 9, bayrak: '\u{1F1E8}\u{1F1ED}'),
  Ulke(kod: 'GB', arama: '44', enAz: 9, enCok: 10, bayrak: '\u{1F1EC}\u{1F1E7}'),
  Ulke(kod: 'US', arama: '1', enAz: 10, enCok: 10, gruplar: [3, 3, 4], bayrak: '\u{1F1FA}\u{1F1F8}'),
  Ulke(kod: 'CA', arama: '1', enAz: 10, enCok: 10, gruplar: [3, 3, 4], bayrak: '\u{1F1E8}\u{1F1E6}'),
  Ulke(kod: 'FR', arama: '33', enAz: 9, enCok: 9, bayrak: '\u{1F1EB}\u{1F1F7}'),
  Ulke(kod: 'BE', arama: '32', enAz: 8, enCok: 9, bayrak: '\u{1F1E7}\u{1F1EA}'),
  Ulke(kod: 'NL', arama: '31', enAz: 9, enCok: 9, bayrak: '\u{1F1F3}\u{1F1F1}'),
  Ulke(kod: 'ES', arama: '34', enAz: 9, enCok: 9, bayrak: '\u{1F1EA}\u{1F1F8}'),
  Ulke(kod: 'IT', arama: '39', enAz: 9, enCok: 10, bayrak: '\u{1F1EE}\u{1F1F9}'),
  Ulke(kod: 'PT', arama: '351', enAz: 9, enCok: 9, bayrak: '\u{1F1F5}\u{1F1F9}'),
  Ulke(kod: 'GR', arama: '30', enAz: 10, enCok: 10, bayrak: '\u{1F1EC}\u{1F1F7}'),
  Ulke(kod: 'CY', arama: '357', enAz: 8, enCok: 8, bayrak: '\u{1F1E8}\u{1F1FE}'),
  Ulke(kod: 'BG', arama: '359', enAz: 8, enCok: 9, bayrak: '\u{1F1E7}\u{1F1EC}'),
  Ulke(kod: 'RO', arama: '40', enAz: 9, enCok: 9, bayrak: '\u{1F1F7}\u{1F1F4}'),
  Ulke(kod: 'PL', arama: '48', enAz: 9, enCok: 9, bayrak: '\u{1F1F5}\u{1F1F1}'),
  Ulke(kod: 'SE', arama: '46', enAz: 7, enCok: 10, bayrak: '\u{1F1F8}\u{1F1EA}'),
  Ulke(kod: 'NO', arama: '47', enAz: 8, enCok: 8, bayrak: '\u{1F1F3}\u{1F1F4}'),
  Ulke(kod: 'DK', arama: '45', enAz: 8, enCok: 8, bayrak: '\u{1F1E9}\u{1F1F0}'),
  Ulke(kod: 'RU', arama: '7', enAz: 10, enCok: 10, bayrak: '\u{1F1F7}\u{1F1FA}'),
  Ulke(kod: 'KZ', arama: '7', enAz: 10, enCok: 10, bayrak: '\u{1F1F0}\u{1F1FF}'),
  Ulke(kod: 'UA', arama: '380', enAz: 9, enCok: 9, bayrak: '\u{1F1FA}\u{1F1E6}'),
  Ulke(kod: 'AZ', arama: '994', enAz: 9, enCok: 9, bayrak: '\u{1F1E6}\u{1F1FF}'),
  Ulke(kod: 'GE', arama: '995', enAz: 9, enCok: 9, bayrak: '\u{1F1EC}\u{1F1EA}'),
  Ulke(kod: 'SA', arama: '966', enAz: 9, enCok: 9, bayrak: '\u{1F1F8}\u{1F1E6}'),
  Ulke(kod: 'AE', arama: '971', enAz: 9, enCok: 9, bayrak: '\u{1F1E6}\u{1F1EA}'),
  Ulke(kod: 'QA', arama: '974', enAz: 8, enCok: 8, bayrak: '\u{1F1F6}\u{1F1E6}'),
  Ulke(kod: 'KW', arama: '965', enAz: 8, enCok: 8, bayrak: '\u{1F1F0}\u{1F1FC}'),
  Ulke(kod: 'BH', arama: '973', enAz: 8, enCok: 8, bayrak: '\u{1F1E7}\u{1F1ED}'),
  Ulke(kod: 'OM', arama: '968', enAz: 8, enCok: 8, bayrak: '\u{1F1F4}\u{1F1F2}'),
  Ulke(kod: 'IQ', arama: '964', enAz: 10, enCok: 10, bayrak: '\u{1F1EE}\u{1F1F6}'),
  Ulke(kod: 'IR', arama: '98', enAz: 10, enCok: 10, bayrak: '\u{1F1EE}\u{1F1F7}'),
  Ulke(kod: 'SY', arama: '963', enAz: 9, enCok: 9, bayrak: '\u{1F1F8}\u{1F1FE}'),
  Ulke(kod: 'JO', arama: '962', enAz: 9, enCok: 9, bayrak: '\u{1F1EF}\u{1F1F4}'),
  Ulke(kod: 'LB', arama: '961', enAz: 7, enCok: 8, bayrak: '\u{1F1F1}\u{1F1E7}'),
  Ulke(kod: 'EG', arama: '20', enAz: 10, enCok: 10, bayrak: '\u{1F1EA}\u{1F1EC}'),
  Ulke(kod: 'MA', arama: '212', enAz: 9, enCok: 9, bayrak: '\u{1F1F2}\u{1F1E6}'),
  Ulke(kod: 'DZ', arama: '213', enAz: 9, enCok: 9, bayrak: '\u{1F1E9}\u{1F1FF}'),
  Ulke(kod: 'TN', arama: '216', enAz: 8, enCok: 8, bayrak: '\u{1F1F9}\u{1F1F3}'),
  Ulke(kod: 'LY', arama: '218', enAz: 9, enCok: 9, bayrak: '\u{1F1F1}\u{1F1FE}'),
  Ulke(kod: 'CN', arama: '86', enAz: 11, enCok: 11, bayrak: '\u{1F1E8}\u{1F1F3}'),
  Ulke(kod: 'IN', arama: '91', enAz: 10, enCok: 10, bayrak: '\u{1F1EE}\u{1F1F3}'),
  Ulke(kod: 'JP', arama: '81', enAz: 9, enCok: 10, bayrak: '\u{1F1EF}\u{1F1F5}'),
  Ulke(kod: 'KR', arama: '82', enAz: 9, enCok: 10, bayrak: '\u{1F1F0}\u{1F1F7}'),
  Ulke(kod: 'AU', arama: '61', enAz: 9, enCok: 9, bayrak: '\u{1F1E6}\u{1F1FA}'),
  Ulke(kod: 'BR', arama: '55', enAz: 10, enCok: 11, bayrak: '\u{1F1E7}\u{1F1F7}'),
  Ulke(kod: 'AR', arama: '54', enAz: 10, enCok: 11, bayrak: '\u{1F1E6}\u{1F1F7}'),
  Ulke(kod: 'MX', arama: '52', enAz: 10, enCok: 10, bayrak: '\u{1F1F2}\u{1F1FD}'),
];

const kVarsayilanUlke = 'TR';

/// ISO koduna göre ülke; bilinmeyen kod -> null (SESSİZCE TR'ye DÜŞMEZ).
Ulke? ulkeBul(String? kod) {
  if (kod == null || kod.isEmpty) return null;
  for (final u in kUlkeler) {
    if (u.kod == kod) return u;
  }
  return null;
}

List<String> _sirali() {
  final k = <String>{for (final u in kUlkeler) u.arama}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return k;
}

/// E.164 bir değerden ülkeyi çözer.
///
/// EN UZUN ARAMA KODU ÖNCE denenir: `+90` ile `+964` aynı `9` ile başlar;
/// kısa kod önce denenirse Irak numarası Türkiye sanılır. Aynı arama kodunu
/// paylaşan ülkelerde listedeki İLK ülke döner — saklama açısından fark
/// yoktur, yalnızca kutuda görünen ISO kodu diğerine ait olabilir.
({Ulke ulke, String ulusal})? ulkeyiCoz(String e164) {
  final s = e164.replaceAll(RegExp(r'\D'), '');
  if (s.isEmpty) return null;
  for (final arama in _sirali()) {
    if (!s.startsWith(arama)) continue;
    final ulusal = s.substring(arama.length);
    final aday = kUlkeler.firstWhere((u) => u.arama == arama);
    // Kod eşleşmesi TEK BAŞINA yeterli değil: kalan hane sayısı da tutmalı.
    if (ulusal.length >= aday.enAz && ulusal.length <= aday.enCok) {
      return (ulke: aday, ulusal: ulusal);
    }
  }
  return null;
}

/// Gruplama verilmemiş ülkeler için: üçerli, son parça 2-4 hane.
List<int> _ucerli(int n) {
  final out = <int>[];
  var kalan = n;
  while (kalan > 4) {
    out.add(3);
    kalan -= 3;
  }
  if (kalan > 0) out.add(kalan);
  return out;
}

/// Ulusal haneleri gruplar: `541 922 23 88`.
String ulusalBicimle(Ulke u, String haneler) {
  if (haneler.isEmpty) return '';
  final gruplar = u.gruplar ?? _ucerli(haneler.length);
  final parcalar = <String>[];
  var i = 0;
  for (final g in gruplar) {
    if (i >= haneler.length) break;
    final son = (i + g) > haneler.length ? haneler.length : i + g;
    parcalar.add(haneler.substring(i, son));
    i = son;
  }
  if (i < haneler.length) parcalar.add(haneler.substring(i));
  return parcalar.join(' ');
}
