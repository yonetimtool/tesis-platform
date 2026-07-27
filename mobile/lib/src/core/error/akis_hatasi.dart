/// Denetleyicilerin (BuildContext YOK) urettigi GENEL hata kimligi.
///
/// KIMLIK / METIN AYRIMI (README §15, `CameraUrlHatasi` emsali): denetleyici
/// gorunen metin uretemez — kimlik dondurur, ekran `akisHataMetni` ile cizim
/// aninda cozer. SUNUCU metinleri (`ApiException.message`) bu kanaldan GECMEZ.
///
/// AG KIMLIKLERI (tur 13): [zamanAsimi] ve [sunucuyaUlasilamadi] SUNUCUDAN
/// gelmez — sozlesme zarfi hic ulasmadiginda ISTEMCI uretir. Tur 13'e kadar
/// metinleri `api_exception.dart` icinde TR sabit olarak duruyordu; artik
/// [ApiException.agHatasi] bu kimligi tasir ve metin burada cozulur.
///
/// Modul-ozel kimlikler (orn. `GorevAkisHatasi`, `DevriyeAkisHatasi`) kendi
/// modullerinde yasar; burada YALNIZ her modulde ayni olan genel durumlar var.
library;

import '../i18n/l10n.dart';
import 'api_exception.dart';

enum AkisHatasi {
  /// Siniflandirilamayan hata.
  beklenmeyen,

  /// Baglanti/gonderim/alim zaman asimi (istemci uretir).
  zamanAsimi,

  /// Sunucuya hic ulasilamadi — DNS/ag yok/kapali port (istemci uretir).
  sunucuyaUlasilamadi,
}

String akisHataMetni(AppLocalizations l10n, AkisHatasi hata) => switch (hata) {
      AkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      AkisHatasi.zamanAsimi => l10n.hataZamanAsimi,
      AkisHatasi.sunucuyaUlasilamadi => l10n.hataSunucuyaUlasilamadi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? akisHatasiCoz(
  AppLocalizations l10n,
  AkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? akisHataMetni(l10n, kimlik) : sunucuMetni;

/// SUNUCU metni ONCE (zaten yerellestirilmis gelir); yoksa ag kimliginden
/// metin uretilir. Hatayi DOGRUDAN gosteren (denetleyiciye ugramayan) her yer
/// `e.message` YERINE bunu kullanmalidir — ag hatalarinda `message` BOS'tur.
String apiHataMetni(AppLocalizations l10n, ApiException e) =>
    e.message.isNotEmpty
        ? e.message
        : akisHataMetni(l10n, e.agHatasi ?? AkisHatasi.beklenmeyen);
