/// Giris/oturum akisinin YERELLESTIRILEBILIR hata kimlikleri.
///
/// Gerekce ve emsal: `tasks/domain/task_hata.dart` (kimlik/metin ayrimi).
/// Denetleyicide `BuildContext` yoktur; metin `presentation/giris_hata_metni`
/// ile cizim aninda cozulur. SUNUCU metinleri (`ApiException.message`) ayri
/// kanaldan (`AuthState.errorMessage`) gecer.
library;

enum GirisAkisHatasi {
  /// Siniflandirilamayan hata.
  beklenmeyen,

  /// Refresh basarisiz — oturum dustu, yeniden giris gerekiyor.
  oturumSonaErdi,
}
