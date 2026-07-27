/// Devriye akis hatasi KIMLIGI -> aktif dildeki metin (bkz. gorev_hata_metni).
library;

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/patrol_hata.dart';

String devriyeHataMetni(AppLocalizations l10n, DevriyeAkisHatasi hata) =>
    switch (hata) {
      DevriyeAkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      DevriyeAkisHatasi.kaydedilemedi => l10n.devriyeKaydedilemedi,
      DevriyeAkisHatasi.agZamanAsimi => l10n.hataZamanAsimi,
      DevriyeAkisHatasi.agUlasilamadi => l10n.hataSunucuyaUlasilamadi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? devriyeHatasiCoz(
  AppLocalizations l10n,
  DevriyeAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? devriyeHataMetni(l10n, kimlik) : sunucuMetni;

/// `ApiException`in AG kimligini bu modulun kimligine cevirir (tur 13).
/// Sunucu metni geldiyse null doner — o zaman metin kanali kullanilir.
DevriyeAkisHatasi? devriyeAgHatasi(ApiException e) => switch (e.agHatasi) {
      AkisHatasi.zamanAsimi => DevriyeAkisHatasi.agZamanAsimi,
      AkisHatasi.sunucuyaUlasilamadi => DevriyeAkisHatasi.agUlasilamadi,
      AkisHatasi.beklenmeyen => DevriyeAkisHatasi.beklenmeyen,
      null => null,
    };
