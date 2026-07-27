/// Gorev akis hatasi KIMLIGI -> aktif dildeki metin.
///
/// `CameraUrlHatasi` emsali: enum domain'de (`task_hata.dart`), `switch` cizim
/// katmaninda. `default` dali YOKTUR — yeni kimlik eklenince derleyici
/// cevirinin yazilmasini ZORLAR.
library;

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/task_hata.dart';

String gorevHataMetni(AppLocalizations l10n, GorevAkisHatasi hata) =>
    switch (hata) {
      GorevAkisHatasi.etiketOkunamadi => l10n.gorevEtiketOkunamadi,
      GorevAkisHatasi.fotoOnlineGerekli => l10n.gorevFotoOnlineGerekli,
      GorevAkisHatasi.fotoOnlineGerekliKisa => l10n.gorevFotoOnlineGerekliKisa,
      GorevAkisHatasi.fotoZorunlu => l10n.gorevFotoZorunluUyari,
      GorevAkisHatasi.fotoHenuzYuklenmedi => l10n.gorevFotoHenuzYuklenmedi,
      GorevAkisHatasi.tamamlamaOffline => l10n.gorevTamamlamaOfflineUyari,
      GorevAkisHatasi.beklenmeyen => l10n.ortakBeklenmeyenHata,
      GorevAkisHatasi.agZamanAsimi => l10n.hataZamanAsimi,
      GorevAkisHatasi.agUlasilamadi => l10n.hataSunucuyaUlasilamadi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni (SERVER-LOCALIZED siniri), o da yoksa null.
String? gorevHatasiCoz(
  AppLocalizations l10n,
  GorevAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? gorevHataMetni(l10n, kimlik) : sunucuMetni;

/// `ApiException`in AG kimligini bu modulun kimligine cevirir (tur 13).
/// Sunucu metni geldiyse null doner — o zaman metin kanali kullanilir.
GorevAkisHatasi? gorevAgHatasi(ApiException e) => switch (e.agHatasi) {
      AkisHatasi.zamanAsimi => GorevAkisHatasi.agZamanAsimi,
      AkisHatasi.sunucuyaUlasilamadi => GorevAkisHatasi.agUlasilamadi,
      AkisHatasi.beklenmeyen => GorevAkisHatasi.beklenmeyen,
      null => null,
    };
