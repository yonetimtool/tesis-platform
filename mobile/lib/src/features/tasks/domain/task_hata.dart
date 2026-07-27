/// Gorev tamamlama akisinin YERELLESTIRILEBILIR hata kimlikleri.
///
/// KIMLIK / METIN AYRIMI (README §15, `CameraUrlHatasi` emsali): denetleyicinin
/// `BuildContext`i yoktur, bu yuzden GORUNEN METIN URETEMEZ — kimlik dondurur,
/// ekran `gorevHataMetni` ile cizim aninda cozer.
///
/// SUNUCU metinleri (`ApiException.message`) bu kanaldan GECMEZ; onlar
/// `SERVER-LOCALIZED(next round)` sinirindadir ve oldugu gibi gosterilir.
library;

enum GorevAkisHatasi {
  /// NFC etiketi okunamadi (surucu/donanim hatasi).
  etiketOkunamadi,

  /// Foto yuklemesi icin baglanti gerekli (uzun aciklama — presign kisa omurlu).
  fotoOnlineGerekli,

  /// Foto yuklemesi icin baglanti gerekli (kisa bicim — yeniden deneme yolu).
  fotoOnlineGerekliKisa,

  /// Gorevde foto kaniti ZORUNLU ama foto yok.
  fotoZorunlu,

  /// Foto secildi ama yuklemesi bitmedi.
  fotoHenuzYuklenmedi,

  /// Tamamlama gonderilemedi — baglanti yok (offline kisiti).
  tamamlamaOffline,

  /// Siniflandirilamayan hata.
  beklenmeyen,

  /// AG: baglanti zaman asimi (istemci uretir — bkz. `AkisHatasi.zamanAsimi`).
  agZamanAsimi,

  /// AG: sunucuya ulasilamadi (istemci uretir).
  agUlasilamadi,
}
