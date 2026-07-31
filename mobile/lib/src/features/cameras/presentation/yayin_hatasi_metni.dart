import '../../../core/i18n/l10n.dart';
import '../domain/yayin_hatasi.dart';

/// [YayinHatasi] -> aktif dildeki ALT SATIR metni (P25b).
///
/// KIMLIK / METIN AYRIMI (README §15): `switch` `default` TASIMAZ — yeni bir
/// neden eklenirse derleyici burayi gosterir ve ceviri atlanamaz.
String yayinHatasiMetni(AppLocalizations l10n, YayinHatasi neden) {
  switch (neden) {
    case YayinHatasi.adresBozuk:
      return l10n.kameraHataAdresBozuk;
    case YayinHatasi.semaDesteklenmiyor:
      return l10n.kameraHataSemaDesteklenmiyor;
    case YayinHatasi.sifrelenmemisEngellendi:
      return l10n.kameraHataSifrelenmemis;
    case YayinHatasi.ulasilamadi:
      // Eski metin: "Kamera kapalı olabilir ya da ağ yayına ulaşamıyor."
      // Diger nedenler ayrildigi icin bu cumle ARTIK DOGRU — once her
      // basarisizlik icin gosteriliyordu ve adres yanlis yazildiginda
      // kullaniciyi kamerayi kontrol etmeye yolluyordu.
      return l10n.kameraYayinAcilamadiAlt;
  }
}
