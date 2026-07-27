/// Seffaflik panosunun YERELLESTIRILEBILIR hata kimlikleri.
///
/// Gerekce ve emsal: `core/error/akis_hatasi.dart` (kimlik/metin ayrimi).
/// Ekran `StatefulWidget` olsa da metin URETMEZ: kimlik tutar,
/// `seffaflikHatasiCoz` cizim aninda cozer.
library;

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';

enum SeffaflikHatasi {
  /// Aylar/pano yuklenemedi (sunucu mesaji yok).
  yuklenemedi,

  /// AG: baglanti zaman asimi (istemci uretir — bkz. `AkisHatasi.zamanAsimi`).
  agZamanAsimi,

  /// AG: sunucuya ulasilamadi (istemci uretir).
  agUlasilamadi,
}

String seffaflikHataMetni(AppLocalizations l10n, SeffaflikHatasi hata) =>
    switch (hata) {
      SeffaflikHatasi.yuklenemedi => l10n.seffafYuklenemedi,
      SeffaflikHatasi.agZamanAsimi => l10n.hataZamanAsimi,
      SeffaflikHatasi.agUlasilamadi => l10n.hataSunucuyaUlasilamadi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? seffaflikHatasiCoz(
  AppLocalizations l10n,
  SeffaflikHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? seffaflikHataMetni(l10n, kimlik) : sunucuMetni;

/// `ApiException`in AG kimligini bu modulun kimligine cevirir (tur 13).
SeffaflikHatasi? seffaflikAgHatasi(ApiException e) => switch (e.agHatasi) {
      AkisHatasi.zamanAsimi => SeffaflikHatasi.agZamanAsimi,
      AkisHatasi.sunucuyaUlasilamadi => SeffaflikHatasi.agUlasilamadi,
      AkisHatasi.beklenmeyen => SeffaflikHatasi.yuklenemedi,
      null => null,
    };
