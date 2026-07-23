import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/phone_login_result.dart';
import 'auth_api.dart';
import 'token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    final result = await api.loginPhone(phone: phone, password: password);
    // Gecici kodla ilk giriste oturum yok — saklanacak token da yok.
    if (result.tokens != null) {
      await storage.save(result.tokens!);
      await storage.saveRememberMe(rememberMe);
      // ON-DOLDURMA: isaretliyse telefon+parolayi sakla, degilse temizle.
      if (rememberMe) {
        await storage.saveCredentials(phone: phone, password: password);
      } else {
        await storage.clearCredentials();
      }
    }
    return result;
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {
    final tokens = await api.setPassword(
      setupToken: setupToken,
      newPassword: newPassword,
    );
    await storage.save(tokens);
    await storage.saveRememberMe(rememberMe);
    // ON-DOLDURMA: ilk giris akisi — telefon biliniyorsa ve isaretliyse sakla.
    if (rememberMe && phone != null && phone.isNotEmpty) {
      await storage.saveCredentials(phone: phone, password: newPassword);
    } else {
      await storage.clearCredentials();
    }
  }

  @override
  Future<({String phone, String password})?> readSavedCredentials() =>
      storage.readCredentials();

  @override
  Future<bool> restoreSession() async {
    if (!await storage.readRememberMe()) {
      // "Hatirla"siz oturumun kalintilari sonraki acilista tasinmaz.
      await storage.clear();
      return false;
    }

    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final tokens = await api.refresh(refreshToken);
      await storage.save(tokens);
      return true;
    } on ApiException catch (e) {
      // Gecici ag hatasinda oturumu koru (sonraki acilis tekrar dener);
      // olu/iptal token'da (auth) kalici oturumu tamamen temizle.
      if (e.kind != ApiErrorKind.network) {
        await storage.clear();
      }
      return false;
    } catch (_) {
      // Beklenmeyen hata acilisi patlatmasin → login ekranina kibar dusus.
      return false;
    }
  }

  @override
  Future<void> logout() => storage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});
