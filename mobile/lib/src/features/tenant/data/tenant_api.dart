import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/tenant_models.dart';

/// Tesis (tenant) ayarlari + ilk-giris kurulumu icin ince HTTP istemcisi.
/// Onboarding Model A: admin isimsiz tesis + yonetici acar; yonetici ILK
/// GIRISTE tesisi adlandirir (`POST /tenant/setup`). Sozlesme: contracts/auth.md
/// §1.4.
class TenantApi {
  TenantApi(this._dio);

  final Dio _dio;

  /// `GET /tenant/settings` — tesis ayarlari (ad + kurulum_tamamlandi).
  Future<TenantSettings> getSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/tenant/settings');
      return TenantSettings.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /tenant/setup` — yonetici tesisi adlandirir (yalniz ilk giriste;
  /// tekrarda 409). Donen ayarda `kurulum_tamamlandi=true`.
  Future<TenantSettings> setup(String ad) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tenant/setup',
        data: {'ad': ad},
      );
      return TenantSettings.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /tenant/settings` — yonetici tesis adini degistirir (yalniz `ad`;
  /// baska alan gonderilirse backend 403 doner). slug DEGISMEZ.
  Future<TenantSettings> updateAd(String ad) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/tenant/settings',
        data: {'ad': ad},
      );
      return TenantSettings.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final tenantApiProvider = Provider<TenantApi>((ref) {
  return TenantApi(ref.watch(dioProvider));
});

/// Oturumdaki tesisin ayarlari — ilk-giris kurulum kapisi (home gate) ve
/// gelecekteki tesis ekranlari icin. Oturum degisince tazelenir.
final tenantSettingsProvider = FutureProvider<TenantSettings>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  return ref.watch(tenantApiProvider).getSettings();
});
