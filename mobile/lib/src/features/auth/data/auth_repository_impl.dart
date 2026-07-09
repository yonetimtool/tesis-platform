import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/auth_repository.dart';
import 'auth_api.dart';
import 'token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  @override
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final tokens = await api.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );
    await storage.save(tokens);
    await storage.saveRememberMe(rememberMe);
  }

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
