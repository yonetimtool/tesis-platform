/// Seffaflik panosunun YERELLESTIRILEBILIR hata kimlikleri.
///
/// Gerekce ve emsal: `core/error/akis_hatasi.dart` (kimlik/metin ayrimi).
/// Ekran `StatefulWidget` olsa da metin URETMEZ: kimlik tutar,
/// `seffaflikHatasiCoz` cizim aninda cozer.
library;

import '../../../core/i18n/l10n.dart';

enum SeffaflikHatasi {
  /// Aylar/pano yuklenemedi (sunucu mesaji yok).
  yuklenemedi,
}

String seffaflikHataMetni(AppLocalizations l10n, SeffaflikHatasi hata) =>
    switch (hata) {
      SeffaflikHatasi.yuklenemedi => l10n.seffafYuklenemedi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? seffaflikHatasiCoz(
  AppLocalizations l10n,
  SeffaflikHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? seffaflikHataMetni(l10n, kimlik) : sunucuMetni;
