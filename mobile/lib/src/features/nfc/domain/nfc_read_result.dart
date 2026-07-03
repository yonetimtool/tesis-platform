/// NFC okuma akisinin domain modelleri. UI ve servis bu tipler uzerinden
/// konusur; ham platform nesneleri (NfcTag, TagPigeon) buraya sizmaz.
library;

/// Algilanan etiketin kaba siniflandirmasi.
///
/// Tam tip tespiti icin uretici komutlari (GET_VERSION) gerekir; burada
/// platformun verdigi teknoloji ipuclarindan turetilen bir tahmin tutulur.
enum NfcTagType {
  /// NTAG213/215/216 ailesi (MIFARE Ultralight tabanli, salt UID + NDEF).
  ntag2xx,

  /// NTAG424 DNA (DESFire/ISO-DEP tabanli, SDM/SUN destekli).
  ntag424,

  /// Teknolojisi siniflandirilamayan etiket.
  unknown,
}

/// NTAG424 SDM (Secure Dynamic Messaging / SUN) ile uretilen URL'den
/// AYRISTIRILAN ham parametreler. Burada KRIPTO YAPILMAZ; sadece etiketin
/// yazdigi degerler yapilandirilmis sekilde tasinir. Dogrulama (CMAC kontrolu,
/// PICCData cozumu) backend'in isidir.
class NfcSdmData {
  const NfcSdmData({
    required this.rawUrl,
    this.piccData,
    this.cmac,
    this.encData,
    this.params = const {},
  });

  /// Etiketten okunan tam URL (NDEF URI kaydi).
  final String rawUrl;

  /// Sifreli PICCData alani (genelde `picc_data` ya da kisa `e` parametresi).
  final String? piccData;

  /// SDM mesaj kimlik kodu (genelde `cmac` ya da kisa `c` parametresi).
  final String? cmac;

  /// Varsa sifreli dosya verisi (genelde `enc`/`d` parametresi).
  final String? encData;

  /// URL'deki tum sorgu parametreleri (ham, dokunulmamis).
  final Map<String, String> params;

  @override
  String toString() =>
      'NfcSdmData(piccData: $piccData, cmac: $cmac, encData: $encData)';
}

/// Tek bir etiket okumasinin sonucu. Basari veya hata; ikisini de tasiyabilir
/// (orn. UID okundu ama SDM ayristirilamadi).
class NfcReadResult {
  const NfcReadResult({
    this.uid,
    this.tagType = NfcTagType.unknown,
    this.sdmData,
    this.readAt,
    this.error,
  });

  /// Etiket UID'i: BUYUK HARF, IKI NOKTA AYRACLI hex (orn. "04:A3:B2:C1:90:00").
  /// Hata veya UID okunamadiginda null.
  final String? uid;

  final NfcTagType tagType;

  /// NTAG424 etiketinde SDM URL'i bulunduysa ayristirilan veri.
  final NfcSdmData? sdmData;

  /// Etiketin okundugu an (UTC). `POST /scans` icin `okutma_zamani` olarak
  /// kullanilir; okuma aninda sabitlenir (offline gecikmeli gonderim icin).
  final DateTime? readAt;

  /// Kullaniciya gosterilecek hata mesaji. null ise okuma basarili.
  final String? error;

  bool get isSuccess => error == null && uid != null;

  factory NfcReadResult.failure(String message) =>
      NfcReadResult(error: message);

  @override
  String toString() =>
      'NfcReadResult(uid: $uid, tagType: ${tagType.name}, sdm: $sdmData, error: $error)';
}
