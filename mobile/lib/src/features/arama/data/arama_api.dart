import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P230 §3) Tek arama sonucu — sunucunun `AramaVurusu` semasi.
class AramaVurusu {
  const AramaVurusu({
    required this.kaynak,
    required this.id,
    required this.baslik,
    this.ayrinti,
  });

  /// `kisi` | `daire` | `gorev` | ... — hedef ekrani BU belirler.
  final String kaynak;
  final String id;
  final String baslik;
  final String? ayrinti;

  factory AramaVurusu.fromJson(Map<String, dynamic> json) => AramaVurusu(
    kaynak: json['kaynak'] as String,
    id: json['id'] as String,
    baslik: json['baslik'] as String? ?? '—',
    ayrinti: json['ayrinti'] as String?,
  );
}

/// (P230 §3) GENEL ARAMA — web'in kullandigi UCUN AYNISI.
///
/// =========================================================================
/// YENI UC ACILMADI
/// =========================================================================
/// `GET /arama?q=` zaten vardi ve web onu kullaniyordu (17 kaynak, rol
/// suzgeci SUNUCUDA: `kaynak.roller` her router'in kendi `require_role`
/// kumesinden okunur). Mobil icin ikinci bir uc yazmak, rol kumelerinin
/// IKINCI bir kopyasi demekti ve biri guncellenip oteki eskidiginde
/// sessiz bir yetki sapmasi uretirdi.
class AramaApi {
  AramaApi(this._dio);

  final Dio _dio;

  Future<List<AramaVurusu>> ara(String q, {CancelToken? iptal}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/arama',
        queryParameters: {'q': q},
        cancelToken: iptal,
      );
      final items = res.data?['items'] as List? ?? const [];
      return items
          .map((e) => AramaVurusu.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const [];
      throw ApiException.fromDio(e);
    }
  }
}

final aramaApiProvider = Provider<AramaApi>((ref) {
  return AramaApi(ref.watch(dioProvider));
});
