import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Saha personeli listesi ogesi (`GET /users` — UserListItem; telefon YOK).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.ad,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String ad;
  final String role;
  final bool isActive;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        ad: json['ad'] as String,
        role: json['role'] as String,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

/// `GET /users` + `POST /users` ince istemcisi (yonetici/admin). Saha personeli
/// = security + tesis_gorevlisi; yonetici backend'de YALNIZ bunlari acabilir.
class StaffApi {
  StaffApi(this._dio);

  final Dio _dio;

  static const fieldRoles = {'security', 'tesis_gorevlisi'};

  Future<List<StaffMember>> getFieldStaff() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/users',
        queryParameters: {'limit': 200},
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items
          .map(StaffMember.fromJson)
          .where((s) => fieldRoles.contains(s.role))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yeni saha personeli. password bossa backend TEK SEFERLIK gecici kod
  /// uretir ve doner (kullaniciya iletilir). Donus: temp_code (varsa).
  Future<String?> addStaff({
    required String ad,
    required String telefon,
    required String role,
    String? password,
  }) async {
    final data = <String, dynamic>{'ad': ad, 'telefon': telefon, 'role': role};
    if (password != null && password.isNotEmpty) data['password'] = password;
    try {
      final res = await _dio.post<Map<String, dynamic>>('/users', data: data);
      return res.data!['temp_code'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /users/{id}` — saha personeli duzenle (ad/rol; telefon opsiyonel,
  /// bos ise degismez). Yonetici backend'de YALNIZ saha personelini duzenler.
  Future<void> updateStaff(
    String id, {
    required String ad,
    required String role,
    String? telefon,
  }) async {
    final data = <String, dynamic>{'ad': ad, 'role': role};
    if (telefon != null && telefon.isNotEmpty) data['telefon'] = telefon;
    try {
      await _dio.patch<Map<String, dynamic>>('/users/$id', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /users/{id}` — aktif/pasif (pasif = personeli listeden cikar; gecmis
  /// korunur, giris engellenir).
  Future<void> setActive(String id, bool active) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/$id',
        data: {'is_active': active},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /users/{id}/reset-password` — parolayi sifirla, yeni TEK SEFERLIK
  /// gecici kod doner (bir kez).
  Future<String> resetPassword(String id) async {
    try {
      final res =
          await _dio.post<Map<String, dynamic>>('/users/$id/reset-password');
      return res.data!['temp_code'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final staffApiProvider =
    Provider<StaffApi>((ref) => StaffApi(ref.watch(dioProvider)));

final fieldStaffProvider = FutureProvider.autoDispose<List<StaffMember>>(
  (ref) => ref.watch(staffApiProvider).getFieldStaff(),
);
