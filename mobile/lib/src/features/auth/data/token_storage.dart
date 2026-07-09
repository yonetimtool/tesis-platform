import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/token_pair.dart';

/// Token'lari [FlutterSecureStorage] (Android: Keystore destekli) ile guvenli
/// saklayan ince sarmalayici.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kRemember = 'auth.remember_me';

  Future<void> save(TokenPair tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  /// "Beni hatirla" bayragi: true ise acilista oturum geri yuklenmeye calisilir.
  Future<void> saveRememberMe(bool value) async {
    if (value) {
      await _storage.write(key: _kRemember, value: 'true');
    } else {
      await _storage.delete(key: _kRemember);
    }
  }

  Future<bool> readRememberMe() async =>
      await _storage.read(key: _kRemember) == 'true';

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kRemember);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Android'de Keystore destekli sifreleme varsayilan olarak kullanilir.
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});
