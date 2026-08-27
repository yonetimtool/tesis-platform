import 'oauth_sonuc.dart';

/// (P154 / Asama 4) SOSYAL GIRIS — AYRI ARAYUZ, bilincli.
///
/// NEDEN `AuthRepository`E EKLENMEDI:
///   * Sosyal giris OPSIYONELDIR. Hicbir saglayici yapilandirilmamissa
///     urun eksiksiz calisir (brief: "tikanirsa Asama 3 tek basina
///     calissin"). Zorunlu kimlik yolu ile opsiyonel bir yolu tek
///     arayuzde toplamak, o ayrimi semadan silerdi.
///   * Kucuk arayuz taklit etmesi kolaydir. Dort metodu ana arayuze
///     eklemek, sosyal girisle hicbir ilgisi olmayan alti test sahtesini
///     dort bos govde yazmaya zorlardi — testlerin okunurlugunu, urunun
///     yapisiyla ilgisi olmayan bir sebeple bozardi.
abstract interface class OauthRepository {
  /// Yapilandirilmis saglayicilar (bos liste = sosyal giris kapali).
  Future<List<String>> saglayicilar();

  /// Tarayici akisini basindan sonuna kosar.
  ///
  /// TEK METOT, UC ADIM (adres al -> tarayici -> sonucu coz) cunku
  /// aralarindaki tek kullanimlik kimligin arayuze sizmasinin faydasi
  /// yok; sizsaydi her cagiran ayni uc adimi yeniden dizerdi.
  ///
  /// `null` YALNIZ VAZGECME demektir (kullanici tarayiciyi kapatti);
  /// basari her zaman bir [OauthSonuc] doner.
  ///
  /// ILK TASARIMDA basari da `null` donuyordu ve cagiran, oturumun acilip
  /// acilmadigini anlamak icin `restoreSession()` cagiriyordu. Bu iki
  /// sebeple yanlisti: (a) "vazgecti" ile "girdi" ayrimini GUVENLI
  /// DEPOYA sormak, cevabi ilgisiz bir yan etkiden okumaktir; (b) test
  /// bunu hemen yakaladi — sahte depo ile bile gercek depo eklentisine
  /// inmeye calisti. Sonucu dogrudan dondurmek ayrimi ACIK kilar.
  ///
  /// Oturum acildiysa jetonlar ZATEN SAKLANMISTIR (`girisYapildi`).
  Future<OauthSonuc?> akis(String saglayici);

  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  });

  /// SMS dogruysa kimligi baglar, jetonlari saklar ve oturumu acar.
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  });

  /// (P184) SSO kimligini bir ROL hesabina baglar — SMS'siz.
  ///
  /// `durum='giris'` iken jetonlar SAKLANIR ve oturum acilir (email_verified
  /// + listede). `otp_gerekli` iken e-postaya kod gitti (`tesisAd` dolu) ve
  /// [rolTamamlaDogrula] ile devam edilir. `onay_bekliyor` iken hesap
  /// ACILMAZ (liste disi ya da gecersiz Tesis ID — AYNI yanit).
  Future<({String durum, String? tesisAd})> rolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
  });

  /// (P184) `email_verified=false` yolunun 2. adimi: e-posta OTP + baglama.
  /// `durum='giris'` iken jetonlar saklanir; `onay_bekliyor` da olabilir.
  Future<({String durum})> rolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
    required String kod,
  });
}
