/// NFC okuma akisinin YERELLESTIRILEBILIR hata kimlikleri + iOS SISTEM
/// sayfasinin metinleri.
///
/// KIMLIK / METIN AYRIMI (README §15): `NfcService` VERI katmanindadir,
/// `BuildContext` gormez — gorunen metin uretemez. Tur 9'a kadar
/// `NfcReadResult.error` TR sabit metin tasiyordu ve tuketici denetleyiciler
/// (gorev/demirbas) bunu "surucu metni" gibi olduğu gibi gosteriyordu; artik
/// KIMLIK tasiyor, metni `presentation/nfc_hata_metni.dart` cozuyor.
///
/// [NfcIosMetinleri] ise TERS yonde akar: iOS'un NFC okuma sayfasini SISTEM
/// cizer, metni bizden parametre olarak alir. Bu yuzden metinler CIZIM
/// katmaninda (`context.l10n`) uretilip servise gecirilir.
library;

enum NfcHatasi {
  /// Cihazda NFC kapali.
  kapali,

  /// Cihaz NFC desteklemiyor.
  desteklenmiyor,

  /// Etiket algilandi ama UID okunamadi.
  uidOkunamadi,

  /// Etiket cozumlenirken beklenmeyen hata ([detay] platform mesaji).
  cozumlenemedi,

  /// Oturum baslatilamadi ([detay] platform mesaji).
  oturumBaslatilamadi,

  /// iOS oturumu kullanici/sistem tarafindan iptal edildi ([detay]).
  okumaIptal,

  /// UYGULAMANIN YAPILANDIRMASI EKSIK — cihaz/kullanici kaynakli DEGIL.
  ///
  /// iOS `NFCReaderError` kodlari `readerErrorSecurityViolation` (kod 2,
  /// "Missing required entitlement"), `readerErrorUnsupportedFeature`,
  /// `readerErrorInvalidParameter*` ve `readerErrorAccessNotAccepted`
  /// bu kimlige duser. AYRI BIR KIMLIK OLMASININ SEBEBI: bunlar
  /// `okumaIptal` diye etiketlenince kullaniciya "tekrar deneyin"
  /// denir — oysa YAPIM duzelmeden hicbir deneme tutmaz. Iki tur
  /// boyunca hata tam bu yuzden yanlis yerde arandi.
  yapilandirmaEksik,

  /// Siniflandirilamayan hata.
  bilinmeyen,
}

/// iOS'un sistem NFC sayfasinda gosterilen metinler. Android'de kullanilmaz
/// (platform kendi arayuzunu cizmez) ama tek imza tutmak icin daima gecirilir.
class NfcIosMetinleri {
  const NfcIosMetinleri({
    required this.yaklastir,
    required this.okundu,
    required this.okunamadi,
    required this.iptal,
  });

  /// Oturum acilirken gosterilen yonlendirme.
  final String yaklastir;

  /// Basarili okumada sayfanin kapanma mesaji.
  final String okundu;

  /// Basarisiz okumada sayfanin hata mesaji.
  final String okunamadi;

  /// Kullanici vazgectiginde sayfanin hata mesaji.
  final String iptal;
}
