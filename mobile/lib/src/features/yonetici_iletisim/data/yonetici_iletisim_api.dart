import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/yonetici_iletisim_models.dart';

/// Yonetici iletisim dizininin ince HTTP istemcisi (kimlikli [dioProvider]).
class YoneticiIletisimApi {
  YoneticiIletisimApi(this._dio);

  final Dio _dio;

  /// `GET /yonetici-iletisim` — tenant'in yoneticileri (birincil ilk) +
  /// yonetim maili.
  Future<YoneticiIletisim> getir() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/yonetici-iletisim');
      return YoneticiIletisim.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final yoneticiIletisimApiProvider = Provider<YoneticiIletisimApi>((ref) {
  return YoneticiIletisimApi(ref.watch(dioProvider));
});

/// Oturumdaki tesisin yonetici dizini. Oturum degisince tazelenir.
final yoneticiIletisimProvider = FutureProvider<YoneticiIletisim>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  return ref.watch(yoneticiIletisimApiProvider).getir();
});
