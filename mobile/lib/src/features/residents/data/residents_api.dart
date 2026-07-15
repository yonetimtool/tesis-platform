import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Site sakini listesi ogesi (`GET /residents`). Telefon KVKK geregi YOK.
class ResidentMember {
  const ResidentMember({
    required this.userId,
    required this.ad,
    this.unitNo,
    required this.isActive,
  });

  final String userId;
  final String ad;
  final String? unitNo;
  final bool isActive;

  factory ResidentMember.fromJson(Map<String, dynamic> json) => ResidentMember(
        userId: json['user_id'] as String,
        ad: json['ad'] as String,
        unitNo: json['unit_no'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

/// Site sakini yonetimi ince istemcisi (yonetici/admin) — listele/ekle/cikar.
class ResidentsApi {
  ResidentsApi(this._dio);

  final Dio _dio;

  Future<List<ResidentMember>> getResidents() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/residents');
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(ResidentMember.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yeni sakin: daire + hesap + gecici kod (password bossa temp_code doner).
  Future<String?> addResident({
    required String ad,
    required String telefon,
    required String unitNo,
    String? password,
  }) async {
    final data = <String, dynamic>{
      'ad': ad,
      'telefon': telefon,
      'unit_no': unitNo,
    };
    if (password != null && password.isNotEmpty) data['password'] = password;
    try {
      final res = await _dio.post<Map<String, dynamic>>('/residents', data: data);
      return res.data!['temp_code'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakini SITEDEN CIKAR (pasiflestir + daire bagini bitir).
  Future<void> removeResident(String userId) async {
    try {
      await _dio.delete<void>('/residents/$userId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final residentsApiProvider =
    Provider<ResidentsApi>((ref) => ResidentsApi(ref.watch(dioProvider)));

final residentsProvider = FutureProvider.autoDispose<List<ResidentMember>>(
  (ref) => ref.watch(residentsApiProvider).getResidents(),
);
