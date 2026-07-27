/// Denetleyicilerin (BuildContext YOK) urettigi GENEL hata kimligi.
///
/// KIMLIK / METIN AYRIMI (README §15, `CameraUrlHatasi` emsali): denetleyici
/// gorunen metin uretemez — kimlik dondurur, ekran `akisHataMetni` ile cizim
/// aninda cozer. SUNUCU metinleri (`ApiException.message`) bu kanaldan GECMEZ.
///
/// Modul-ozel kimlikler (orn. `GorevAkisHatasi`, `DevriyeAkisHatasi`) kendi
/// modullerinde yasar; burada YALNIZ her modulde ayni olan genel durum var.
library;

import '../i18n/l10n.dart';

enum AkisHatasi {
  /// Siniflandirilamayan hata.
  beklenmeyen,
}

String akisHataMetni(AppLocalizations l10n, AkisHatasi hata) => switch (hata) {
      AkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? akisHatasiCoz(
  AppLocalizations l10n,
  AkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? akisHataMetni(l10n, kimlik) : sunucuMetni;
