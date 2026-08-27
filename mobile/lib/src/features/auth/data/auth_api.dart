import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/oauth_sonuc.dart';
import '../domain/phone_login_result.dart';
import '../domain/token_pair.dart';

/// Auth endpoint'lerinin ince HTTP istemcisi. DioException'lari sozlesme hata
/// zarfina gore [ApiException]'a cevirir.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /auth/login-phone` — mobil giris: cep telefonu (global benzersiz) +
  /// (kod|parola). Tenant numaradan otomatik cozulur (tenant_slug YOK). Gecici
  /// kodla ilk giriste `password_setup_required=true` + `setup_token` doner.
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login-phone',
        data: {'phone': phone, 'password': password},
      );
      return PhoneLoginResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P149) `POST /auth/giris/kod-iste` — PAROLASIZ giris: numaraya kod
  /// gonderilir. Numara KAYITLI OLMASA DA ayni yanit doner (sunucu numara
  /// varligini sizdirmaz), bu yuzden istemci de "numara yok" DEMEZ.
  Future<void> girisKoduIste(String telefon) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/giris/kod-iste',
        data: {'telefon': telefon},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ==================== (P154 / Asama 4) SOSYAL GIRIS ==================== #
  //
  // MOBIL YEREL SDK KULLANMAZ, TARAYICI AKISINI KULLANIR. Gerekce:
  //   * Apple "Sign in with Apple" geri donus adresinde https ISTER; ozel
  //     sema kabul etmez. Tarayici akisinda saglayici yalniz arka ucun
  //     https callback'ini gorur, ozel semaya donusu BIZ yapariz.
  //   * Boylece her saglayicida KAYDEDILECEK TEK BIR adres kalir; mobil
  //     icin ayri istemci/anahtar kaydi gerekmez.
  //   * Ve dogrulama TEK yerde olur (arka uc). Yerel SDK jetonu ayri bir
  //     dogrulama yolu acardi ve `aud`/`iss` kontrolunun ikinci bir
  //     kopyasi demekti.

  /// `GET /auth/oauth/saglayicilar` — hangi dugmeler cizilecek?
  ///
  /// Yapilandirilmamis saglayiciyi gostermek, kullaniciyi KESIN BASARISIZ
  /// bir yola sokmak olurdu.
  Future<List<String>> oauthSaglayicilar() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/auth/oauth/saglayicilar',
      );
      final ham = res.data?['saglayicilar'];
      if (ham is! List) return const [];
      return ham.map((e) => e.toString()).toList(growable: false);
    } on DioException {
      // SESSIZ: sosyal giris bir EK yoldur. Listeyi alamamak parola/kod
      // girisini engellememeli (brief: "tikanirsa Asama 3 tek basina
      // calissin").
      return const [];
    }
  }

  /// `POST /auth/oauth/baslat/{saglayici}` — yetkilendirme adresi.
  Future<String> oauthBaslat(String saglayici) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/baslat/$saglayici',
        data: {'yuzey': 'mobil'},
      );
      return res.data!['adres'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/oauth/sonuc` — tek kullanimlik sonucu coz.
  ///
  /// Iki sonuctan biri: oturum acildi (`jetonlar`) ya da hesap eslesmesi
  /// gerekiyor (`baglama_jetonu`). Ikincisi brief'in merkez kurali:
  /// sosyal hesap kimlik dogrulama YONTEMIDIR, eslesme anahtari degil.
  Future<OauthSonuc> oauthSonuc(String sonucId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/sonuc',
        data: {'sonuc_id': sonucId},
      );
      return OauthSonuc.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/oauth/baglan/basla` — tesis kodu + telefon; eslesirse SMS.
  ///
  /// ESLESME SONUCU YANITTAN OKUNAMAZ (`rolKayitBasla` ile ayni ilke).
  Future<({String tesisAd, String telefonMaskeli})> oauthBaglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/baglan/basla',
        data: {
          'baglama_jetonu': baglamaJetonu,
          'tesis_kodu': tesisKodu,
          'telefon': telefon,
        },
      );
      return (
        tesisAd: res.data!['tesis_ad'] as String,
        telefonMaskeli: res.data!['telefon_maskeli'] as String,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/oauth/baglan/dogrula` — SMS dogruysa baglar VE oturum acar.
  Future<TokenPair> oauthBaglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/baglan/dogrula',
        data: {
          'baglama_jetonu': baglamaJetonu,
          'telefon': telefon,
          'kod': kod,
        },
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ================= (P184) E-POSTA DOGRULAMALI KAYIT ================= #
  //
  // SMS YERINE E-POSTA. Telefon yolundaki (`rolKayitBasla`/`oauthBaglan*`)
  // kardesler DURUYOR ama mobil ARTIK CAGIRMIYOR: `SMS_AKTIF=false` ve
  // dogrulama tek kanali e-posta. Telefon yalniz ILETISIM bilgisidir.

  /// (P184) `POST /auth/kayit/rol-eposta-basla` — rol + Tesis ID + e-posta;
  /// eslesirse E-POSTAYA kod gonderilir. Eslesme sonucu YANITTAN OKUNAMAZ
  /// (`rolKayitBasla` ile ayni ilke) — istemci "adres yok" DEMEZ.
  Future<String> rolEpostaBasla({
    required String rol,
    required String tesisKodu,
    required String eposta,
    String? ad,
    String? telefon,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/kayit/rol-eposta-basla',
        data: {
          'rol': rol,
          'tesis_kodu': tesisKodu,
          'eposta': eposta,
          if (ad != null && ad.isNotEmpty) 'ad': ad,
          if (telefon != null && telefon.isNotEmpty) 'telefon': telefon,
        },
      );
      return res.data!['tesis_ad'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P184) `POST /auth/kayit/rol-eposta-dogrula` — kod dogruysa PAROLA
  /// belirleme jetonu (`durum='hazir'`); uc sart tutmazsa `onay_bekliyor`.
  /// TEK YANIT TIPI, IKI SONUC — hangi sartin tutmadigi SIZDIRILMAZ.
  Future<({String durum, String? setupToken})> rolEpostaDogrula({
    required String tesisKodu,
    required String eposta,
    required String kod,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/kayit/rol-eposta-dogrula',
        data: {'tesis_kodu': tesisKodu, 'eposta': eposta, 'kod': kod},
      );
      return (
        durum: res.data!['durum'] as String,
        setupToken: res.data!['setup_token'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P184) `POST /auth/oauth/rol-tamamla` — SSO kimligini rol hesabina
  /// baglar (SMS'siz). `durum`:
  ///   * `giris`        — email_verified=true + listede -> oturum (`jetonlar`).
  ///   * `otp_gerekli`  — saglayici e-postayi dogrulamamis -> e-posta OTP
  ///                      gonderildi (`tesisAd` dolu); `oauthRolTamamlaDogrula`.
  ///   * `onay_bekliyor`— liste disi VEYA gecersiz Tesis ID (AYNI yanit).
  Future<({String durum, String? tesisAd, TokenPair? jetonlar})>
      oauthRolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/rol-tamamla',
        data: {
          'baglama_jetonu': baglamaJetonu,
          'tesis_kodu': tesisKodu,
          'rol': rol,
        },
      );
      final j = res.data!['jetonlar'];
      return (
        durum: res.data!['durum'] as String,
        tesisAd: res.data!['tesis_ad'] as String?,
        jetonlar:
            j == null ? null : TokenPair.fromJson(j as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P184) `POST /auth/oauth/rol-tamamla-dogrula` — email_verified=false
  /// yolunun 2. adimi: e-posta OTP + baglama. `durum`: giris | onay_bekliyor.
  Future<({String durum, TokenPair? jetonlar})> oauthRolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
    required String kod,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/oauth/rol-tamamla-dogrula',
        data: {
          'baglama_jetonu': baglamaJetonu,
          'tesis_kodu': tesisKodu,
          'rol': rol,
          'kod': kod,
        },
      );
      final j = res.data!['jetonlar'];
      return (
        durum: res.data!['durum'] as String,
        jetonlar:
            j == null ? null : TokenPair.fromJson(j as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P154 / Asama 3) `POST /auth/kayit/rol-basla` — rol + tesis ID +
  /// telefon; eslesirse SMS kodu gonderilir.
  ///
  /// ESLESME SONUCU YANITTAN OKUNAMAZ: numara o tesiste o rolde kayitli
  /// olsa da olmasa da yanit AYNIDIR (sunucu bilerek sizdirmiyor). Bu
  /// yuzden istemci de "numara bulunamadi" DEMEZ — yalniz kod ekranina
  /// gecer ve kodun gelmeyebilecegini yazar.
  ///
  /// Donen `tesis_ad`, kullanicinin dogru tesisi sectigini teyit etmesi
  /// icindir; tesis kodu KAMUYA ACIK oldugu icin bunu gostermek bir sey
  /// sizdirmaz (bkz. goc 0037 guvenlik notu).
  Future<({String tesisAd, String telefonMaskeli})> rolKayitBasla({
    required String rol,
    required String tesisKodu,
    required String telefon,
    String? daireNo,
    String? blok,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/kayit/rol-basla',
        data: {
          'rol': rol,
          'tesis_kodu': tesisKodu,
          'telefon': telefon,
          if (daireNo != null && daireNo.isNotEmpty) 'daire_no': daireNo,
          if (blok != null && blok.isNotEmpty) 'blok': blok,
        },
      );
      return (
        tesisAd: res.data!['tesis_ad'] as String,
        telefonMaskeli: res.data!['telefon_maskeli'] as String,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P155r2 / §3) `POST /auth/kayit/tesis-olustur` — YONETICI SELF-SIGNUP.
  ///
  /// Tesis O ANDA olusur, kodu sunucu uretir ve OTURUM ACILIR; admin
  /// paneli adimi yoktur. Donen `tesisKodu` ilk ekranda gosterilir
  /// cunku yoneticinin sakinlerine iletecegi sey odur.
  ///
  /// YONTEM TEK: ya `parola` ya `baglamaJetonu`. Ikisini birden
  /// gondermek sunucuda 422'dir; bu yuzden cagiran tarafta da ayrilar.
  Future<({String tesisAd, String tesisKodu, TokenPair jetonlar})>
      tesisOlustur({
    required String tesisAd,
    required String ad,
    required String telefon,
    String? parola,
    String? baglamaJetonu,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/kayit/tesis-olustur',
        data: {
          'tesis_ad': tesisAd,
          'ad': ad,
          'telefon': telefon,
          if (parola != null && parola.isNotEmpty) 'parola': parola,
          if (baglamaJetonu != null && baglamaJetonu.isNotEmpty)
            'baglama_jetonu': baglamaJetonu,
        },
      );
      return (
        tesisAd: res.data!['tesis_ad'] as String,
        tesisKodu: res.data!['tesis_kodu'] as String,
        jetonlar: TokenPair.fromJson(
          res.data!['jetonlar'] as Map<String, dynamic>,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P154 / Asama 3) `POST /auth/kayit/rol-dogrula` — kod dogruysa
  /// PAROLA BELIRLEME jetonu doner (oturum DEGIL).
  ///
  /// Jeton yalniz `/auth/set-password`te gecer; kayit, parola
  /// belirlenene kadar tamamlanmis sayilmaz.
  Future<String> rolKayitDogrula({
    required String telefon,
    required String kod,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/kayit/rol-dogrula',
        data: {'telefon': telefon, 'kod': kod},
      );
      return res.data!['setup_token'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P149) `POST /auth/giris/kod-dogrula` — kod dogruysa TAM OTURUM.
  /// Parola akisindan farkli olarak `setup_token` asamasi YOKTUR: parolasiz
  /// kullanicinin belirleyecegi bir parola da yoktur.
  Future<TokenPair> girisKoduDogrula({
    required String telefon,
    required String kod,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/giris/kod-dogrula',
        data: {'telefon': telefon, 'kod': kod},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/set-password` — ilk giristeki zorunlu parola belirleme.
  /// Basarida tam oturum (TokenPair) doner; gecici kod sunucuda silinir.
  Future<TokenPair> setPassword({
    required String setupToken,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/set-password',
        data: {'setup_token': setupToken, 'new_password': newPassword},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/refresh` — refresh token ile yeni cift al (rotation).
  Future<TokenPair> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ==================== (P155 §7) DAVET ==================== #

  /// `POST /davet/coz` — jetonu cozer; tesis/rol/daire/telefon(maskeli)/ad.
  /// COZME jetonu TUKETMEZ (derin baglanti tarayicida da acilabilir).
  Future<DavetCozum> davetCoz(String jeton) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/davet/coz',
        data: {'jeton': jeton},
      );
      final d = res.data!;
      return DavetCozum(
        tesisAd: d['tesis_ad'] as String,
        rol: d['rol'] as String,
        ad: d['ad'] as String,
        telefonMaskeli: d['telefon_maskeli'] as String,
        daireNo: d['daire_no'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /davet/parola` — davetle gelen kullanici parola belirler (SMS
  /// YOK); tam oturum doner.
  Future<TokenPair> davetParola({
    required String jeton,
    String? ad,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/davet/parola',
        data: {
          'jeton': jeton,
          if (ad != null && ad.isNotEmpty) 'ad': ad,
          'new_password': newPassword,
        },
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /davet/sosyal` — davetle gelen kullanici sosyal hesabini baglar
  /// (SMS YOK); tam oturum doner.
  Future<TokenPair> davetSosyal({
    required String jeton,
    required String baglamaJetonu,
    String? ad,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/davet/sosyal',
        data: {
          'jeton': jeton,
          'baglama_jetonu': baglamaJetonu,
          if (ad != null && ad.isNotEmpty) 'ad': ad,
        },
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// (P155 §7) Cozulmus davet baglami — mobil davet ekrani bunu gosterir.
class DavetCozum {
  const DavetCozum({
    required this.tesisAd,
    required this.rol,
    required this.ad,
    required this.telefonMaskeli,
    this.daireNo,
  });

  final String tesisAd;
  final String rol;
  final String ad;
  final String telefonMaskeli;
  final String? daireNo;
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
