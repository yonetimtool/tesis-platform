import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/token_storage.dart';

/// Backend'e kaydedilmis FCM token'in yerel isareti. Logout'ta hangi token'in
/// pasiflestirilecegini bilmek icin saklanir (uygulama yeniden acilsa bile).
class PushTokenStore {
  PushTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kRegistered = 'push.registered_fcm_token';

  Future<String?> read() => _storage.read(key: _kRegistered);

  Future<void> save(String token) =>
      _storage.write(key: _kRegistered, value: token);

  Future<void> clear() => _storage.delete(key: _kRegistered);
}

final pushTokenStoreProvider = Provider<PushTokenStore>((ref) {
  return PushTokenStore(ref.watch(secureStorageProvider));
});
