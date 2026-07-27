/// Gorev akis hatasi KIMLIGI -> aktif dildeki metin.
///
/// `CameraUrlHatasi` emsali: enum domain'de (`task_hata.dart`), `switch` cizim
/// katmaninda. `default` dali YOKTUR — yeni kimlik eklenince derleyici
/// cevirinin yazilmasini ZORLAR.
library;

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
    };

/// Kimlik ONCE, yoksa SUNUCU metni (SERVER-LOCALIZED siniri), o da yoksa null.
String? gorevHatasiCoz(
  AppLocalizations l10n,
  GorevAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null ? gorevHataMetni(l10n, kimlik) : sunucuMetni;
