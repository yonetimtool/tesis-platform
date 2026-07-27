/// Talep akisinin YERELLESTIRILEBILIR hata kimlikleri.
///
/// KIMLIK / METIN AYRIMI (README §15, `CameraUrlHatasi` emsali): denetleyicinin
/// `BuildContext`i yoktur — kimlik dondurur, ekran cizim aninda cozer.
/// SUNUCU metinleri (`ApiException.message`) bu kanaldan GECMEZ.
library;

enum TalepAkisHatasi {
  /// Kategori listesi alinamadi (sunucu mesaji yok).
  kategorilerYuklenemedi,

  /// Foto secilemedi/okunamadi (ayrintisi metin kanalinda tasinir).
  fotoAlinamadi,

  /// Foto yuklemesi icin baglanti gerekli (presign kisa omurlu).
  fotoOnlineGerekli,

  /// Foto yuklemesi siniflandirilamayan nedenle basarisiz.
  fotoYuklenemedi,
  /// AG: baglanti zaman asimi (istemci uretir — bkz. `AkisHatasi.zamanAsimi`).
  agZamanAsimi,

  /// AG: sunucuya ulasilamadi (istemci uretir).
  agUlasilamadi,
}
