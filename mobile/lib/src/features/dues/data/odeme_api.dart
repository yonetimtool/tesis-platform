import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Sakin "Öde" akisi (P30) istemcisi.
///
/// `GET /me/odeme-bilgileri` TEK cagridir: IBAN + kod + borc birlikte gelir,
/// cunku ekranin tek isi "nereye, ne kadar, hangi kodla" demektir; iki cagri
/// ekrani iki yukleme durumuna bolerdi.
class OdemeApi {
  OdemeApi(this._dio);
  final Dio _dio;

  Future<OdemeBilgileri> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/odeme-bilgileri');
      return OdemeBilgileri.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Kart odemesi baslat. Sahte/manuel saglayicida ANINDA basarili doner.
  Future<KartOdemeSonuc> kartOde(int tutarKurus) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/odeme/kart',
        data: {'tutar_kurus': tutarKurus},
      );
      return KartOdemeSonuc.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class OdemeBilgileri {
  const OdemeBilgileri({
    required this.odemeKodu,
    required this.borcKurus,
    required this.kartAktif,
    this.iban,
    this.bankaAdi,
  });

  /// Sitenin anlasmali banka kasasinin IBAN'i. `null` ise havale secenegi
  /// GIZLENIR — yanlis IBAN gostermektense hic gostermemek dogru.
  final String? iban;
  final String? bankaAdi;

  /// Havale aciklamasina yazilacak BENZERSIZ kod (sabit).
  final String odemeKodu;
  final int borcKurus;

  /// Saglayici yapilandirilmis mi. Manuel saglayici "kart" DEGILDIR.
  final bool kartAktif;

  factory OdemeBilgileri.fromJson(Map<String, dynamic> j) => OdemeBilgileri(
        iban: j['iban'] as String?,
        bankaAdi: j['banka_adi'] as String?,
        odemeKodu: j['odeme_kodu'] as String? ?? '',
        borcKurus: (j['borc_kurus'] as num?)?.toInt() ?? 0,
        kartAktif: j['kart_aktif'] as bool? ?? false,
      );
}

class KartOdemeSonuc {
  const KartOdemeSonuc({required this.durum, this.odemeUrl});

  final String durum;
  final String? odemeUrl;

  bool get basarili => durum == 'basarili';

  factory KartOdemeSonuc.fromJson(Map<String, dynamic> j) => KartOdemeSonuc(
        durum: j['durum'] as String? ?? '',
        odemeUrl: j['odeme_url'] as String?,
      );
}

final odemeApiProvider = Provider<OdemeApi>((ref) => OdemeApi(ref.watch(dioProvider)));

final odemeBilgileriProvider =
    FutureProvider.autoDispose<OdemeBilgileri>((ref) {
  return ref.watch(odemeApiProvider).fetch();
});
