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
      final res = await _dio.post<Map<String, dynamic>>(
        '/residents',
        data: data,
      );
      return res.data!['temp_code'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakini duzenle (P23b) — OLUSTURMADAKI TUM ALANLAR.
  ///
  /// Bos birakilan alan GONDERILMEZ (degismez). Iki istisna:
  ///   * [emailTemizle] true ise `email: null` ACIKCA gonderilir (sunucu
  ///     alani temizler) — "bos birakmak" ile "silmek" ayri seylerdir.
  ///   * [rolTipi] verilirse kullanicinin AKTIF daire baglarinin HEPSINE
  ///     uygulanir; aktif bagi yoksa sunucu 422 doner.
  Future<void> updateResident(
    String userId, {
    String? ad,
    String? telefon,
    String? email,
    bool emailTemizle = false,
    String? rolTipi,
  }) async {
    final data = <String, dynamic>{};
    if (ad != null && ad.isNotEmpty) data['ad'] = ad;
    if (telefon != null && telefon.isNotEmpty) data['telefon'] = telefon;
    if (emailTemizle) {
      data['email'] = null;
    } else if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (rolTipi != null && rolTipi.isNotEmpty) data['rol_tipi'] = rolTipi;
    try {
      await _dio.patch<void>('/residents/$userId', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakin parolasini sifirla — yeni gecici kod doner (bir kez).
  Future<String> resetPassword(String userId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/residents/$userId/reset-password',
      );
      return res.data!['temp_code'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakini SIL (akilli) — telefon her durumda serbest kalir. Donus: tamamen
  /// silindi mi (true) yoksa pasiflestirildi mi (false, gecmisi var).
  Future<bool> removeResident(String userId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/residents/$userId');
      return (res.data?['deleted'] as bool?) ?? true;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final residentsApiProvider = Provider<ResidentsApi>(
  (ref) => ResidentsApi(ref.watch(dioProvider)),
);

final residentsProvider = FutureProvider.autoDispose<List<ResidentMember>>(
  (ref) => ref.watch(residentsApiProvider).getResidents(),
);
