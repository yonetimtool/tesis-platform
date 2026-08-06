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

  /// `POST /me/hesap-sil` — SELF-SERVIS HESAP SILME (P112).
  ///
  /// App Store 5.1.1(v): hesap acilabiliyorsa UYGULAMA ICINDEN
  /// silinebilmeli. Parola YENIDEN sorulur (odunc alinmis telefonla tek
  /// dokunusta silme olmasin).
  ///
  /// Doner: **tam silindi mi**. `false` BASARISIZLIK DEGILDIR — hesabin
  /// gecmisi (aidat/odeme) oldugu icin satir anonimlestirilerek korundu
  /// demektir; kullaniciya iki durumda da farkli ama OLUMLU metin gosterilir.
  /// (P149) Silme onay KODU iste — parolasiz kullanici icin.
  Future<void> hesapSilmeKoduIste() async {
    try {
      await _dio.post<Map<String, dynamic>>('/me/hesap-sil/kod-iste');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// [currentPassword] parolasi OLANLAR icin, [kod] parolasiz kullanici
  /// icin. Hangisinin gecerli oldugunu SUNUCU secer — istemci tahmin etmez.
  Future<bool> deleteAccount({String? currentPassword, String? kod}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/hesap-sil',
        data: {
          'current_password': ?currentPassword,
          'kod': ?kod,
        },
      );
      return res.data?['deleted'] == true;
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
