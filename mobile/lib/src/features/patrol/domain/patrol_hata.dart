/// Devriye denetleyicilerinin YERELLESTIRILEBILIR hata kimlikleri.
///
/// Gerekce ve emsal: `tasks/domain/task_hata.dart` (kimlik/metin ayrimi).
library;

enum DevriyeAkisHatasi {
  /// Siniflandirilamayan hata (denetleyici metin uretemez).
  beklenmeyen,

  /// Plan kaydedilemedi (sunucu mesaji yok).
  kaydedilemedi,
}
