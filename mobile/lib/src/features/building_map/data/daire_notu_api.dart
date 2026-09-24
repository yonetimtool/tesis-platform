import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P247-bekleyen 1.2) DAIRE NOTLARI — `/ekler?varlik_tipi=unit`.
///
/// SUZME SUNUCUDA: saha personeli (guvenlik, tesis gorevlisi) yalniz
/// yonetimin "saha gorebilir" diye isaretledigi notlari ALIR; isaretsiz
/// not yanitta hic yer almaz. Bu istemci karar vermez, yalniz tasir.
class DaireNotu {
  const DaireNotu({
    required this.id,
    required this.tur,
    this.metin,
    this.dosyaAdi,
    this.sahaGorebilir = false,
  });

  final String id;
  final String tur;
  final String? metin;
  final String? dosyaAdi;
  final bool sahaGorebilir;

  factory DaireNotu.fromJson(Map<String, dynamic> j) => DaireNotu(
        id: j['id'] as String? ?? '',
        tur: j['tur'] as String? ?? 'not',
        metin: j['metin'] as String?,
        dosyaAdi: j['dosya_adi'] as String? ?? j['dosya_key'] as String?,
        sahaGorebilir: j['saha_gorebilir'] as bool? ?? false,
      );
}

class DaireNotuApi {
  DaireNotuApi(this._dio);

  final Dio _dio;

  Future<List<DaireNotu>> listele(String unitId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/ekler',
        queryParameters: {'varlik_tipi': 'unit', 'varlik_id': unitId},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => DaireNotu.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Not ekler. `sahaGorebilir` VARSAYILAN KAPALI; yalniz yonetim cagirir.
  Future<void> ekle(String unitId, String metin, {required bool sahaGorebilir}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/ekler',
        data: {
          'varlik_tipi': 'unit',
          'varlik_id': unitId,
          'tur': 'not',
          'metin': metin,
          'saha_gorebilir': sahaGorebilir,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> sahaGorunurlugu(String ekId, {required bool sahaGorebilir}) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/ekler/$ekId',
        data: {'saha_gorebilir': sahaGorebilir},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final daireNotuApiProvider =
    Provider<DaireNotuApi>((ref) => DaireNotuApi(ref.watch(dioProvider)));
