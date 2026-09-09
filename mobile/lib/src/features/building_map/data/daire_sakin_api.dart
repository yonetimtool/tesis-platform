import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P220 §5) BIR DAIRENIN SAKIN BAGLARI — bina duzenleme penceresi icin.
///
/// ===========================================================================
/// NEDEN AYRI BIR ISTEMCI
/// ===========================================================================
/// `residents_api.dart` SITE GENELINDEKI sakin listesini yonetiyor
/// (`/residents`). Buradaki soru farkli: "BU DAIREDE kim oturuyor".
/// Ikisini tek istemcide toplamak, iki farkli kavrami (kisi / daire bagi)
/// ayni yerde tutmak olurdu.
class DaireSakini {
  const DaireSakini({
    required this.id,
    required this.userId,
    required this.ad,
    required this.rolTipi,
    required this.oturuyor,
  });

  final String id;
  final String userId;

  /// Kayit silinmisse `null` gelebilir; arayuz UUID GOSTERMEZ, "—" der.
  final String? ad;

  /// 'malik' | 'kiraci' | null (rol atanmamis)
  final String? rolTipi;

  /// (P218) MULKIYETTEN AYRI bir gercek: malik oturuyor da olabilir,
  /// oturmuyor da. KMK md. 20 isletme giderini KULLANANA, bakim/onarim
  /// giderini MALIKE yukluyor — "malik-oturan" ucuncu bir rol degil,
  /// malikin oturuyor olmasi.
  final bool oturuyor;

  factory DaireSakini.fromJson(Map<String, dynamic> j) => DaireSakini(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        ad: j['user_ad'] as String?,
        rolTipi: j['rol_tipi'] as String?,
        oturuyor: (j['oturuyor'] as bool?) ?? false,
      );
}

class DaireSakinApi {
  DaireSakinApi(this._dio);
  final Dio _dio;

  /// AKTIF baglar (bitis IS NULL). Gecmis baglar filtreleniyor: daire
  /// penceresinin sorusu "SU ANDA kim oturuyor".
  Future<List<DaireSakini>> listele(String unitId) async {
    try {
      final r = await _dio.get<List<dynamic>>('/units/$unitId/residents');
      return (r.data ?? const [])
          .cast<Map<String, dynamic>>()
          .where((x) => x['bitis'] == null)
          .map(DaireSakini.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> ekle(String unitId, String userId, String? rolTipi) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/units/$unitId/residents',
        data: {'user_id': userId, if (rolTipi != null) 'rol_tipi': rolTipi},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P220 §5) YALNIZ BU DAIREDEKI bagi gunceller.
  ///
  /// `PATCH /residents/{id}` KULLANILMIYOR: o uc kullanicinin AKTIF TUM
  /// baglarina uyguluyor. Iki dairesi olan bir sakinde (birinde malik,
  /// otekinde kiraci) daire penceresinden yapilan degisiklik IKISINI DE
  /// degistirirdi.
  Future<void> guncelle(
    String unitId,
    String userId, {
    String? rolTipi,
    bool? oturuyor,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/units/$unitId/residents/$userId',
        data: {
          if (rolTipi != null) 'rol_tipi': rolTipi,
          if (oturuyor != null) 'oturuyor': oturuyor,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Bagi kapatir (sakini daireden cikarir). HESABI SILMEZ: kisi siteden
  /// ayrilmadiysa baska bir daireye tasinmis olabilir.
  Future<void> cikar(String unitId, String userId) async {
    try {
      await _dio.delete<void>('/units/$unitId/residents/$userId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final daireSakinApiProvider =
    Provider<DaireSakinApi>((ref) => DaireSakinApi(ref.watch(dioProvider)));

final daireSakinleriProvider =
    FutureProvider.autoDispose.family<List<DaireSakini>, String>(
  (ref, unitId) => ref.watch(daireSakinApiProvider).listele(unitId),
);
