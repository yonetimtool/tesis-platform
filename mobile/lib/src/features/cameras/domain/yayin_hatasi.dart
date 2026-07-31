/// Yayin acilamama NEDENI (P25b) — tek bir "açılamadı" cumlesi yerine.
///
/// NEDEN AYRI BIR KIMLIK: oynatici eskiden her basarisizlikta ayni metni
/// gosteriyordu. Kullanicinin yapabilecegi sey ise nedene gore TAMAMEN
/// FARKLIDIR: adres yanlis yazilmissa duzeltir, kamera kapaliysa bekler,
/// adres `rtsp://` ise bir restream gecidi tanimlamasi gerekir. Ayni cumle
/// bu uc durumu tek bir cikmaza cevirir.
///
/// KIMLIK / METIN AYRIMI (README §15): bu enum METIN TASIMAZ; cumle
/// `yayin_hatasi_metni.dart` icinde aktif dilden cozulur.
library;

/// [yayinHatasiCoz] icin ham girdi: adres + platformun firlattigi nesne.
enum YayinHatasi {
  /// Adres `Uri.parse` edilemedi (bosluk, satir sonu, yapistirma artigi).
  /// ESKIDEN CAKILIYORDU: `Uri.parse` `try` blogunun DISINDA cagriliyordu,
  /// bozuk adres yakalanmamis bir `FormatException` firlatiyordu.
  adresBozuk,

  /// Sema oynatilamaz (`rtsp://`, `rtmp://` …) ve restream gecidi yok.
  semaDesteklenmiyor,

  /// Adres sifrelenmemis (`http://`) ve platform engelledi. Android 9+ ile
  /// iOS ATS bunu varsayilan olarak keser; uygulama artik izin veriyor ama
  /// kurumsal profil/VPN yine kesebilir.
  sifrelenmemisEngellendi,

  /// Baglanti kurulamadi / zaman asimi / 4xx-5xx.
  ulasilamadi,
}

/// Oynatilamayan semalar — `hls`/`mp4` disindaki her sey buraya duser.
const _oynatilamazSemalar = {'rtsp', 'rtmp', 'rtsps', 'srt', 'webrtc'};

/// Adres OYNATICIYA verilebilir mi (sema + konak var, bosluk yok).
///
/// `Uri.tryParse` TEK BASINA YETMEZ: Dart'in cozumleyicisi HOSGORULUDUR ve
/// `https://ornek /a.m3u8` gibi ICINDE BOSLUK tasiyan bir adresi hatasiz
/// cozer (bosluk yola girer). Oysa gercek dunyada bu, yapistirma artigi olan
/// BOZUK bir adrestir ve oynatici acilmadan duser — kullaniciya "kamera
/// kapali olabilir" demek yanlis teshis olurdu.
bool adresOynatilabilirMi(String url) {
  final temiz = url.trim();
  if (temiz.isEmpty) return false;
  // Satir sonu / sekme / ic bosluk: yapistirma artigi.
  if (RegExp(r'\s').hasMatch(temiz)) return false;
  final uri = Uri.tryParse(temiz);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

/// Adres + hatadan NEDEN uret.
///
/// Once ADRESIN KENDISI incelenir (elde kesin bilgi vardir), ancak ondan
/// sonra platform hatasina bakilir: platform mesajlari surume ve cihaza gore
/// degisir, adres ise degismez.
YayinHatasi yayinHatasiCoz(String url, Object? hata) {
  final temiz = url.trim();
  if (!adresOynatilabilirMi(temiz)) return YayinHatasi.adresBozuk;
  final uri = Uri.parse(temiz);
  if (_oynatilamazSemalar.contains(uri.scheme.toLowerCase())) {
    return YayinHatasi.semaDesteklenmiyor;
  }
  if (uri.scheme.toLowerCase() == 'http' && _cleartextIzi(hata)) {
    return YayinHatasi.sifrelenmemisEngellendi;
  }
  return YayinHatasi.ulasilamadi;
}

/// Platformun cleartext engelini bildiren izler.
///
/// Android `CLEARTEXT communication ... not permitted` der; iOS ATS ise
/// "App Transport Security policy requires the use of a secure connection".
/// Ikisi de metindir — bu yuzden EK KOSUL olarak kullanilir, tek basina
/// karar vermez (adresin `http` olmasi zaten kontrol edildi).
bool _cleartextIzi(Object? hata) {
  if (hata == null) return false;
  final m = hata.toString().toLowerCase();
  return m.contains('cleartext') || m.contains('app transport security');
}
