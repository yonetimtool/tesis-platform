/// Giris akis hatasi KIMLIGI -> aktif dildeki metin (bkz. gorev_hata_metni).
library;

import '../../../core/i18n/l10n.dart';
import '../domain/giris_hatasi.dart';

String girisHataMetni(AppLocalizations l10n, GirisAkisHatasi hata) =>
    switch (hata) {
      GirisAkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      GirisAkisHatasi.oturumSonaErdi => l10n.girisOturumSonaErdi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? girisHatasiCoz(
  AppLocalizations l10n,
  GirisAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? girisHataMetni(l10n, kimlik) : sunucuMetni;
