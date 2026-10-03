import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P253 Asama 1) NOT VE EK — `/ekler` (web `components/Ekler.tsx` ikizi).
///
/// Her varliga (gorev, daire, bakim kaydi...) takilan notlar ve dosyalar
/// TEK zaman cizgisi. Yetki sunucuda: okuma ust kaydi gorene, yazma ve
/// silme ust kayda yazabilene (ya da ekin sahibine).
class Ek {
  const Ek({
    required this.id,
    required this.tur,
    this.metin,
    this.dosyaAdi,
    this.dosyaUrl,
    this.olusturanAd,
    this.createdAt,
  });

  final String id;

  /// `not` | `dosya`.
  final String tur;
  final String? metin;
  final String? dosyaAdi;
  final String? dosyaUrl;
  final String? olusturanAd;
  final DateTime? createdAt;

  /// Onay diyaloglarinda ve listede ekin ADI: dosya adi ya da notun basi.
  String get gorunenAd {
    final ham = tur == 'dosya' ? (dosyaAdi ?? '') : (metin ?? '');
    final tek = ham.replaceAll(RegExp(r'\s+'), ' ').trim();
    return tek.length > 40 ? '${tek.substring(0, 40)}…' : tek;
  }

  factory Ek.fromJson(Map<String, dynamic> j) => Ek(
    id: j['id'] as String? ?? '',
    tur: j['tur'] as String? ?? 'not',
    metin: j['metin'] as String?,
    dosyaAdi: j['dosya_adi'] as String? ?? j['dosya_key'] as String?,
    dosyaUrl: j['dosya_url'] as String?,
    olusturanAd: j['olusturan_ad'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
  );
}

class EkApi {
  EkApi(this._dio);

  final Dio _dio;

  Future<List<Ek>> listele(String varlikTipi, String varlikId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/ekler',
        queryParameters: {'varlik_tipi': varlikTipi, 'varlik_id': varlikId},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Ek.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> notEkle(String varlikTipi, String varlikId, String metin) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/ekler',
        data: {'varlik_tipi': varlikTipi, 'varlik_id': varlikId, 'tur': 'not', 'metin': metin},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /ekler/{ek_id}` — geri alinamaz (sunucu satiri siler).
  Future<void> sil(String ekId) async {
    try {
      await _dio.delete<void>('/ekler/$ekId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final ekApiProvider = Provider<EkApi>((ref) => EkApi(ref.watch(dioProvider)));

/// (varlik_tipi, varlik_id) -> ekler.
final ekListesiProvider = FutureProvider.autoDispose.family<List<Ek>, (String, String)>(
  (ref, a) => ref.watch(ekApiProvider).listele(a.$1, a.$2),
);
