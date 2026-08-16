import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kurulum_models.dart';

/// (P166 §8.2) `/kurulum` istemcisi — web ile AYNI UC.
///
/// RBAC (sunucu zorlar): admin + yonetici. Saha ve sakin 403 alir; bu
/// yuzden ekran/hatirlatici o rollerde HIC cagirmaz — bosa 403 uretmek
/// gunlukleri kirletir ve hicbir sey kazandirmaz.
class KurulumApi {
  KurulumApi(this._dio);

  final Dio _dio;

  Future<KurulumDurum> durum() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/kurulum');
      return KurulumDurum.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Adimi atla / atlamayi geri al. Sunucu GUNCEL DURUMU doner — istemci
  /// kendi kopyasini duzeltmek zorunda kalmaz (ve iki taraf ayrisamaz).
  Future<KurulumDurum> atla(String kod, {required bool atla}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/kurulum',
        data: {'kod': kod, 'atla': atla},
      );
      return KurulumDurum.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final kurulumApiProvider = Provider<KurulumApi>(
  (ref) => KurulumApi(ref.watch(dioProvider)),
);

/// Sihirbaz durumu. Oturum degisince tazelenir (baska tesise giris).
final kurulumDurumProvider = FutureProvider<KurulumDurum>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  return ref.watch(kurulumApiProvider).durum();
});
