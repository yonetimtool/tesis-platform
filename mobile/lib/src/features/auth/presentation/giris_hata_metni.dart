/// Giris akis hatasi KIMLIGI -> aktif dildeki metin (bkz. gorev_hata_metni).
library;

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/giris_hatasi.dart';

String girisHataMetni(AppLocalizations l10n, GirisAkisHatasi hata) =>
    switch (hata) {
      GirisAkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      GirisAkisHatasi.oturumSonaErdi => l10n.girisOturumSonaErdi,
      GirisAkisHatasi.agZamanAsimi => l10n.hataZamanAsimi,
      GirisAkisHatasi.agUlasilamadi => l10n.hataSunucuyaUlasilamadi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? girisHatasiCoz(
  AppLocalizations l10n,
  GirisAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? girisHataMetni(l10n, kimlik) : sunucuMetni;

/// `ApiException`in AG kimligini bu modulun kimligine cevirir (tur 13).
/// Sunucu metni geldiyse null doner — o zaman metin kanali kullanilir.
GirisAkisHatasi? girisAgHatasi(ApiException e) => switch (e.agHatasi) {
      AkisHatasi.zamanAsimi => GirisAkisHatasi.agZamanAsimi,
      AkisHatasi.sunucuyaUlasilamadi => GirisAkisHatasi.agUlasilamadi,
      AkisHatasi.beklenmeyen => GirisAkisHatasi.beklenmeyen,
      null => null,
    };
