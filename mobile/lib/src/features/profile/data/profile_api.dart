import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/profile.dart';

/// Self-servis profil uclarinin ince HTTP istemcisi (kimlikli [dioProvider]).
/// DioException'lari sozlesme hata zarfina gore [ApiException]'a cevirir.
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  /// `GET /me/profile` — kendi kimlik + iletisim alanlari.
  Future<Profile> getProfile() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/profile');
      return Profile.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /me/password` — mevcut parola dogrulanir; 204 doner.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.patch<void>(
        '/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /me/contact` — kendi telefon + arama rizasi (en az bir alan).
  Future<Profile> updateContact({String? telefon, bool? aranabilir}) async {
    final data = <String, dynamic>{};
    if (telefon != null) data['telefon'] = telefon;
    if (aranabilir != null) data['aranabilir'] = aranabilir;
    try {
      final res =
          await _dio.patch<Map<String, dynamic>>('/me/contact', data: data);
      return Profile.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final profileApiProvider =
    Provider<ProfileApi>((ref) => ProfileApi(ref.watch(dioProvider)));

/// Profil ekrani acilisinda yuklenen kendi profilim. Iletisim guncellemesinden
/// sonra `ref.invalidate(profileProvider)` ile tazelenir.
final profileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileApiProvider).getProfile(),
);
