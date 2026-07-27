/// Devriye akis hatasi KIMLIGI -> aktif dildeki metin (bkz. gorev_hata_metni).
library;

import '../../../core/i18n/l10n.dart';
import '../domain/patrol_hata.dart';

String devriyeHataMetni(AppLocalizations l10n, DevriyeAkisHatasi hata) =>
    switch (hata) {
      DevriyeAkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      DevriyeAkisHatasi.kaydedilemedi => l10n.devriyeKaydedilemedi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? devriyeHatasiCoz(
  AppLocalizations l10n,
  DevriyeAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? devriyeHataMetni(l10n, kimlik) : sunucuMetni;
