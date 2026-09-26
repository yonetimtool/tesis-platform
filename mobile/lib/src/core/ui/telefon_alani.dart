/// (P123 · P227 §3 · P233 §3) TELEFON GİRİŞİ — TEK biçimlendirici, TEK
/// kural, HER alan.
///
/// =========================================================================
/// (P233 §3) TR SABİTİ KALKTI — ÜLKE KODU ARTIK DEĞERİN PARÇASI
/// =========================================================================
/// Eskiden bu dosya TR'ye sabitti (gerekçe: `ulke_telefon.dart` baş yorumu).
/// Kullanıcının gördüğü değer artık ülke kodunu TAŞIR:
/// `(+90) 541 922 23 88`.
///
/// Ülke AYRI bir parametre olsaydı telefon girilen YEDİ ekranın her biri
/// ikinci bir durum parçası taşımak zorunda kalırdı ve sekizincisi onu
/// unuturdu. Değerin kendisi ülkeyi taşıyınca unutulacak parça kalmıyor.
///
/// =========================================================================
/// GÖSTERİM İLE SAKLAMA AYRI
/// =========================================================================
/// Sunucuya giden değer yine E.164 (`+905419222388`) — `normalize_phone`
/// boşluk/parantez siler, biçim değişiminden ETKİLENMEZ. Telefon GLOBAL
/// BENZERSİZ anahtar olduğu için ikisini karıştırmak eski kayıtları
/// erişilemez kılardı.
///
/// BAŞTAKİ `0` KALKTI: `0(543) 199 29 04` -> `(+90) 543 199 29 04`. Ülke
/// kodu görünürken ayrıca ulusal `0` öngöster bulundurmak numarayı iki kez
/// "ülkelendirmek" olurdu.
///
/// Panel ikizi `admin-web/lib/telefon.ts` ile AYNI tabloyu üretir.
library;

import 'package:flutter/services.dart';

import 'ulke_telefon.dart';

export 'ulke_telefon.dart';

/// TR hane sayısı — geriye dönük; yeni kod ülkenin `enAz/enCok`unu okur.
const kTelefonHaneSayisi = 10;

final _tr = ulkeBul(kVarsayilanUlke)!;

/// Ham dizgeyi (ülke, ulusal haneler) çiftine ayırır.
///
/// ÜLKE NEREDEN OKUNUR — sırayla:
///  1. `(+90) ...` / `+90...` / `0090...` — AÇIK ülke kodu.
///  2. Baştaki tek `0` (`0543...`) — ESKİ TR biçimi; hâlâ gelebilir
///     (yapıştırma, rehber, eski kayıt).
///  3. Hiçbiri yoksa ÜLKE YOK döner — sessizce TR sayılmaz; sessiz varsayım
///     bu turun düzelttiği kusurun ta kendisi.
({Ulke? ulke, String haneler}) telefonParcala(String ham) {
  final metin = ham.trim();
  var s = metin.replaceAll(RegExp(r'\D'), '');
  if (s.isEmpty) return (ulke: null, haneler: '');

  final acikKod = metin.contains('+') || s.startsWith('00');
  if (s.startsWith('00')) s = s.substring(2);

  if (acikKod) {
    final c = ulkeyiCoz(s);
    if (c != null) return (ulke: c.ulke, haneler: c.ulusal);
    // Kod tanınıyor ama hane sayısı henüz tutmuyor (kullanıcı YAZIYOR):
    // en uzun eşleşen kodu soy, kalanı ulusal say.
    final kodlar = <String>{for (final u in kUlkeler) u.arama}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final arama in kodlar) {
      if (s.startsWith(arama)) {
        return (
          ulke: kUlkeler.firstWhere((u) => u.arama == arama),
          haneler: s.substring(arama.length),
        );
      }
    }
    return (ulke: null, haneler: s);
  }

  if (s.startsWith('0')) return (ulke: _tr, haneler: s.substring(1));

  // (P233 §3) `+` YOKSA DA ULKE KODU ARANIR — ama YALNIZ hane sayisi TAM
  // tuttugunda. `905431992904` numarayi yazmanin cok yaygin bir bicimidir
  // (backend `kimlik.py` bunun icin ayrica telafi tasiyor) ve ilk yazimda
  // TASMA sayiliyordu: 12 hane, TR siniri 10. Olcum yakaladi.
  //
  // Hane sayisi TUTMAK ZORUNDA: aksi halde `5431992904` -> AR (`+54`) diye
  // cozulur ve kullanicinin yazdigi TR numarasi Arjantin numarasina
  // donerdi. Tam eslesme sarti bunu imkansiz kilar.
  final c = ulkeyiCoz(s);
  if (c != null) return (ulke: c.ulke, haneler: c.ulusal);
  return (ulke: null, haneler: s);
}

/// Ulusal haneler (ülke kodu HARİÇ), ülkenin en çok hanesine KIRPILMIŞ.
String telefonHaneleri(String ham) {
  final p = telefonParcala(ham);
  final sinir = (p.ulke ?? _tr).enCok;
  return p.haneler.length > sinir ? p.haneler.substring(0, sinir) : p.haneler;
}

/// (P227 §3) Hane sınırı aşıldı mı — KESMEDEN ÖNCE sorulur.
///
/// `telefonHaneleri` fazla haneyi SESSİZCE kesiyordu: kullanıcı 11. rakamı
/// yazdığında ekranda hiçbir şey değişmiyor, numarayı doğru sandığı hâlde
/// son hanesi düşmüş oluyordu.
bool telefonTasti(String ham) {
  final p = telefonParcala(ham);
  return p.haneler.length > (p.ulke ?? _tr).enCok;
}

/// `(+90) 541 922 23 88` — eksikse kısmi. Ülke yoksa yalnız gövde.
String telefonBicimle(String haneler, Ulke? ulke) {
  final govde = ulusalBicimle(ulke ?? _tr, haneler);
  if (ulke == null) return govde;
  return govde.isEmpty ? '(+${ulke.arama}) ' : '(+${ulke.arama}) $govde';
}

/// Kutuda görünecek ULUSAL kısım (ülke kodu AYRI kutuda çizildiği için).
String telefonUlusal(String ham) {
  final p = telefonParcala(ham);
  return ulusalBicimle(p.ulke ?? _tr, telefonHaneleri(ham));
}

/// Sunucuya gidecek değer — E.164. Ülke yoksa BOŞ (yanlış kod uydurulmaz).
String telefonNormalle(String ham) {
  final p = telefonParcala(ham);
  final h = telefonHaneleri(ham);
  if (h.isEmpty || p.ulke == null) return '';
  return '+${p.ulke!.arama}$h';
}

/// Ülke kodunu DEĞİŞTİRİR, girilmiş haneleri korur.
String telefonUlkeyiDegistir(String ham, String kod) {
  final u = ulkeBul(kod);
  if (u == null) return ham;
  final h = telefonParcala(ham).haneler;
  final kirpik = h.length > u.enCok ? h.substring(0, u.enCok) : h;
  return telefonBicimle(kirpik, u);
}

/// Girdi biçimlendirici — ULUSAL kutu için: yazarken gruplar, rakam dışını
/// yutar, uzunluğu **sert** sınırlar.
///
/// Ülke DIŞARIDAN verilir çünkü sınır ülkeye göre değişir; biçimlendirici
/// kendi başına ülkeyi bilemez (kutuda ülke kodu YOK).
class TelefonBicimlendirici extends TextInputFormatter {
  const TelefonBicimlendirici([this.ulke]);

  final Ulke? ulke;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    // YAPIŞTIRILAN METİN KENDİ ÜLKE KODUNU GETİRDİYSE dokunma: çağıran
    // ekran onu `telefonParcala` ile çözüp ülke kutusunu günceller.
    if (yeni.text.contains('+')) return yeni;

    final u = ulke ?? _tr;
    // BASTAKI SIFIRLAR ATILIR (`0543…` -> `543…`): ülke kodu ayrı kutuda
    // dururken alana ulusal gövde ekini (`0`) de yazmak numarayı iki kez
    // "ülkelendirmek" olur ve TAŞMA üretir (ölçüldü). Hiçbir ülkede ulusal
    // anlamlı numara `0` ile başlamaz.
    var haneler =
        yeni.text.replaceAll(RegExp(r'\D'), '').replaceAll(RegExp(r'^0+'), '');
    if (haneler.length > u.enCok) haneler = haneler.substring(0, u.enCok);
    final metin = ulusalBicimle(u, haneler);

    // FAZLA HANE YAZILAMAZ: sınır doluyken yeni rakam metni DEĞİŞTİRMEZ.
    // İmleci de eski yerinde bırakmak gerekir, aksi hâlde her tuşta imleç
    // sona sıçrar ve ortadan düzeltme yapmak imkânsızlaşır.
    if (metin == eski.text) return eski;

    final imlecHane = yeni.text
        .substring(0, yeni.selection.end.clamp(0, yeni.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;
    return TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(
        offset: _haneninEkranKonumu(metin, imlecHane),
      ),
    );
  }

  /// [n] hane girildiğinde imlecin biçimli metindeki konumu.
  ///
  /// **n'inci hanenin ARDI** döner: imleç yazılan rakamdan SONRA durur. İlk
  /// yazımda bu bir eksikti ve her tuşta imleç bir karakter geride kalıyordu
  /// — kullanıcı 5 hane yazınca altıncıyı bir önceki hanenin soluna yazardı.
  static int _haneninEkranKonumu(String metin, int n) {
    if (metin.isEmpty) return 0;
    if (n <= 0) return 0;
    final rakam = RegExp(r'\d');
    var sayac = 0;
    for (var i = 0; i < metin.length; i++) {
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

  /// Ülkenin en az hane sayısından kısa.
  eksik,

  /// TR'de `5` ile başlamıyor (sabit hat / hatalı ön ek).
  gecersizOnEk,

  /// (P227 §3) Ülkenin en çok hanesinden UZUN — sessizce kesilmez, SÖYLENİR.
  tasma,

  /// (P233 §3) Ülke kodu seçilmemiş.
  ulkeYok,
}

/// [ham] için hata kimliği; `null` = geçerli.
///
/// (P248 §2) [sabitHat]: firma/işletme numarası — TR cep ön eki (`5`)
/// ARANMAZ. Kişiye ait alanlarda verilmez (panel ikiziyle aynı).
TelefonHatasi? telefonHatasi(
  String ham, {
  bool zorunlu = true,
  bool sabitHat = false,
}) {
  final p = telefonParcala(ham);
  // (P227 §3) TAŞMA ÖNCE SORULUR: numara kırpıldığı için aşağıdaki
  // denetimlerin hepsi GEÇERLİ görünür ve kullanıcı hatayı HİÇ görmezdi.
  if (p.haneler.length > (p.ulke ?? _tr).enCok) return TelefonHatasi.tasma;
  if (p.haneler.isEmpty) return zorunlu ? TelefonHatasi.bos : null;
  if (p.ulke == null) return TelefonHatasi.ulkeYok;
  // ÖN EK KURALI YALNIZ TR'DE: diğer ülkelerin cep bloklarını doğrulamak
  // için elimizde güvenilir veri yok; uydurulmuş bir kural gerçek bir
  // numarayı reddederdi.
  final onEk = p.ulke!.mobilOnEk;
  if (!sabitHat && onEk != null && !p.haneler.startsWith(onEk)) {
    return TelefonHatasi.gecersizOnEk;
  }
  if (p.haneler.length < p.ulke!.enAz) return TelefonHatasi.eksik;
  return null;
}

/// TR ön ek kuralı — geriye dönük ad (P123'ten beri çağrılıyor).
bool telefonOnEkiGecerli(String haneler) =>
    haneler.isEmpty || haneler.startsWith('5');

/// (P248 §2) GİRİŞ KİMLİĞİ TELEFON MU — tek alanlı giriş (P205) için.
///
/// KARAR: alan RAKAM, `+` ya da `(` ile başlayıp YALNIZ telefon
/// karakterleri taşıyorsa (rakam, boşluk, `+ ( ) - .`) telefon moduna
/// geçilir; harf ya da `@` görülünce e-posta modunda kalınır. Panel ikizi
/// `admin-web/lib/telefon.ts` `kimlikTelefonMu` ile AYNI kural.
bool kimlikTelefonMu(String metin) {
  final s = metin.trim();
  if (s.isEmpty) return false;
  return RegExp(r'^[\d+(]').hasMatch(s) &&
      RegExp(r'^[\d\s+().\-]+$').hasMatch(s);
}

/// (P248 §2) Giriş ucuna gidecek kimlik: telefonsa E.164, değilse kırpılmış
/// metin. Ülke çözülemezse HAM metin gider — sunucu son kararı verir.
String kimlikGonderimDegeri(String ham) {
  final s = ham.trim();
  if (!kimlikTelefonMu(s)) return s;
  final e164 = telefonNormalle(s);
  return e164.isEmpty ? s : e164;
}
