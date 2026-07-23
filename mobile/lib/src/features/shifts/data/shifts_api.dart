import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/shift_models.dart';

/// GET /shifts istemcisi — salt okuma (yazma admin panelden). RBAC: admin +
/// yonetici + security + tesis_gorevlisi (auth.md §4).
class ShiftsApi {
  ShiftsApi(this._dio);
  final Dio _dio;

  Future<List<Shift>> fetch({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/shifts',
      queryParameters: {'limit': limit},
    );
    return [
      for (final item in (res.data?['items'] as List?) ?? const [])
        if (item is Map) Shift.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}

final shiftsApiProvider = Provider<ShiftsApi>((ref) {
  return ShiftsApi(ref.watch(dioProvider));
});

/// Vardiya tanimlari — saha + yonetici ana ekran "Vardiya Durumu" bolumu.
/// Hata → izleyen ekran bolumu sessizce gizler (ana ekran rehin degil).
final shiftsProvider = FutureProvider.autoDispose<List<Shift>>((ref) {
  return ref.watch(shiftsApiProvider).fetch();
});
