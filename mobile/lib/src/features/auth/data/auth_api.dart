import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
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
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
