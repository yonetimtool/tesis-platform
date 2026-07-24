import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;

/// GET /users öğesinden avatar_url (SAF — test edilebilir).
String? avatarUrlFromUsers(Map<String, dynamic> json) =>
    json['avatar_url'] as String?;

/// Saha personeli listesi ogesi (`GET /users` — UserListItem; telefon YOK).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.ad,
    required this.role,
    required this.isActive,
    this.avatarUrl,
  });

  final String id;
  final String ad;
  final String role;
  final bool isActive;

  /// Profil fotografi (P3) — yonetici yukler; presign GET URL (varsa).
  final String? avatarUrl;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        ad: json['ad'] as String,
        role: json['role'] as String,
        isActive: (json['is_active'] as bool?) ?? true,
        avatarUrl: json['avatar_url'] as String?,
      );
}

/// `GET /users` + `POST /users` ince istemcisi (yonetici/admin). Saha personeli
/// = security + tesis_gorevlisi; yonetici backend'de YALNIZ bunlari acabilir.
class StaffApi {
  StaffApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio; // presigned PUT: auth header'siz temiz istemci

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
  /// uretir ve doner (kullaniciya iletilir). Donus: (id, tempCode) — id foto
  /// yukleme icin (`setStaffAvatar`) kullanilir.
  Future<({String id, String? tempCode})> addStaff({
    required String ad,
    required String telefon,
    required String role,
    String? password,
  }) async {
    final data = <String, dynamic>{'ad': ad, 'telefon': telefon, 'role': role};
    if (password != null && password.isNotEmpty) data['password'] = password;
    try {
      final res = await _dio.post<Map<String, dynamic>>('/users', data: data);
      return (
        id: res.data!['id'] as String,
        tempCode: res.data!['temp_code'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — foto obje anahtari + kisa omurlu PUT URL.
  Future<PresignTicket> presignUpload({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'personel.jpg'},
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _uploadDio.put<void>(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: bytes.length,
      }),
    );
  }

  /// Saha personeli avatarini ata/kaldir (`PATCH /users/{id}/avatar` — yalniz
  /// yonetici; sunucu zorlar). null fotografi kaldirir.
  Future<void> setStaffAvatar(String id, String? fotoKey) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/$id/avatar',
        data: {'avatar_key': fotoKey},
      );
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
