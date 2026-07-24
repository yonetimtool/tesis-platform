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

  /// Vardiya personelini TAM LISTE olarak degistirir (admin+yonetici).
  Future<void> updateAssignments(String shiftId, List<String> userIds) async {
    await _dio.put<Map<String, dynamic>>(
      '/shifts/$shiftId/assignments',
      data: {'user_ids': userIds},
    );
  }
}

final shiftsApiProvider = Provider<ShiftsApi>((ref) {
  return ShiftsApi(ref.watch(dioProvider));
});

/// Atanabilir saha personeli (admin+yonetici cagirir; GET /users RBAC'i).
/// security + tesis_gorevlisi kullanicilarini ShiftPersonel olarak doner.
final atanabilirPersonelProvider =
    FutureProvider.autoDispose<List<ShiftPersonel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final out = <ShiftPersonel>[];
  for (final role in ['security', 'tesis_gorevlisi']) {
    final res = await dio.get<Map<String, dynamic>>(
      '/users', queryParameters: {'role': role, 'limit': 200},
    );
    for (final item in (res.data?['items'] as List?) ?? const []) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        out.add(ShiftPersonel(
            userId: m['id'] as String? ?? '', ad: m['ad'] as String? ?? ''));
      }
    }
  }
  return out;
});

/// Vardiya tanimlari — saha + yonetici ana ekran "Vardiya Durumu" bolumu.
/// Hata → izleyen ekran bolumu sessizce gizler (ana ekran rehin degil).
final shiftsProvider = FutureProvider.autoDispose<List<Shift>>((ref) {
  return ref.watch(shiftsApiProvider).fetch();
});
