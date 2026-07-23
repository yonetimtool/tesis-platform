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
  // "Beni hatirla" ON-DOLDURMA icin saklanan giris bilgileri. Parola YALNIZ
  // burada (Keystore destekli secure storage) tutulur; asla loglanmaz/gonderilmez
  // (normal giris cagrisi disinda). Login ekrani acilista bunlarla alanlari doldurur.
  static const _kSavedPhone = 'auth.saved_phone';
  static const _kSavedPassword = 'auth.saved_password';

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

  /// "Beni hatirla" isaretliyken cagrilir: sonraki girislerde ON-DOLDURMA icin
  /// telefon + parolayi saklar (ikisi de Keystore/secure storage'da).
  Future<void> saveCredentials({
    required String phone,
    required String password,
  }) async {
    await _storage.write(key: _kSavedPhone, value: phone);
    await _storage.write(key: _kSavedPassword, value: password);
  }

  /// Saklanan giris bilgileri (telefon + parola) ya da yoksa null.
  Future<({String phone, String password})?> readCredentials() async {
    final phone = await _storage.read(key: _kSavedPhone);
    final password = await _storage.read(key: _kSavedPassword);
    if (phone == null || phone.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return (phone: phone, password: password);
  }

  /// ON-DOLDURMA bilgilerini siler ("beni hatirla" kaldirilinca / isaretsiz giriste).
  Future<void> clearCredentials() async {
    await _storage.delete(key: _kSavedPhone);
    await _storage.delete(key: _kSavedPassword);
  }

  /// Oturumu (token'lar + bayrak) siler. ON-DOLDURMA bilgilerine DOKUNMAZ —
  /// boylece logout sonrasi login ekrani yine on-dolu gelir (bkz. [clearCredentials]).
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
