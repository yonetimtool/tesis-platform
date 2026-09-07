import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

/// (DUKKAN F4) DUKKAN JETONU — Yonetiyor SSO koprusuyle alinir.
///
/// =========================================================================
/// NEDEN AYRI JETON
/// =========================================================================
/// Yonetiyor JWT'si `tenant_id` ZORUNLU tasir; Dukkan jetonu tasimaz
/// (Dukkan cok-kiracili degil). Iki jeton dunyasi ayri ve birbirinin
/// ucunda GECERSIZ — sunucu tarafinda testle kilitli.
///
/// =========================================================================
/// %27 — TELEFONSUZ KULLANICI KENAR DURUM DEGIL
/// =========================================================================
/// Olculdu: Yonetiyor'daki 3104 kullanicinin 837'sinde (%27) telefon YOK.
/// Kopru bu durumda 409 `telefon_gerekli` doner. Bu bir HATA EKRANI gibi
/// degil, akisin NORMAL bir dali gibi ele alinmali: kullanici telefon-OTP
/// akisina yonlendirilir.
///
/// F4'te mobilde OTP akisi HENUZ YOK; bu durumda kullaniciya ne oldugu
/// ACIKCA soyleniyor ve web'e yonlendiriliyor. Sessizce bos bir ekran
/// gostermek, her dort kullanicidan birini akisin ortasinda birakirdi.
class DukkanOturumHatasi implements Exception {
  DukkanOturumHatasi(this.kod);

  /// 'telefon_gerekli' | 'yonetiyor_jetonu_gecersiz' | 'hesap_askida' | 'ag'
  final String kod;

  @override
  String toString() => 'DukkanOturumHatasi($kod)';
}

class DukkanOturum {
  DukkanOturum(this._dio);

  final Dio _dio;
  String? _jeton;

  String? get jeton => _jeton;

  /// Yonetiyor oturumuyla Dukkan jetonu alir. Doner: jeton.
  ///
  /// Hata halinde `DukkanOturumHatasi` firlatir — sessizce `null`
  /// dondurmek, cagiranin "jeton yok mu, hata mi" ayrimini yapamamasi
  /// demekti.
  Future<String> jetonAl() async {
    final mevcut = _jeton;
    if (mevcut != null) return mevcut;
    try {
      // `dio` Yonetiyor jetonunu `auth_interceptor` ile zaten ekliyor;
      // kopru o jetonu okuyup Dukkan jetonu uretiyor.
      final r = await _dio.post<Map<String, dynamic>>('/dukkan/auth/yonetiyor');
      final j = r.data?['access_token'] as String?;
      if (j == null) throw DukkanOturumHatasi('yanit_bos');
      _jeton = j;
      return j;
    } on DioException catch (e) {
      final kod = (e.response?.data is Map)
          ? '${(e.response!.data as Map)['error']?['code'] ?? ''}'
          : '';
      if (e.response?.statusCode == 409) {
        throw DukkanOturumHatasi('telefon_gerekli');
      }
      if (e.response?.statusCode == 403) {
        throw DukkanOturumHatasi('hesap_askida');
      }
      if (e.response?.statusCode == 401) {
        throw DukkanOturumHatasi('yonetiyor_jetonu_gecersiz');
      }
      throw DukkanOturumHatasi(kod.isEmpty ? 'ag' : kod);
    }
  }

  void temizle() => _jeton = null;
}

final dukkanOturumProvider =
    Provider<DukkanOturum>((ref) => DukkanOturum(ref.watch(dioProvider)));
