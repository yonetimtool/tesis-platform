import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) async {
    final tokens = await api.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );
    await storage.save(tokens);
  }

  @override
  Future<bool> hasSession() async {
    final refresh = await storage.readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
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
