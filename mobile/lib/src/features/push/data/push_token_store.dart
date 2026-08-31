import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/token_storage.dart';

/// Backend'e kaydedilmis FCM token'in yerel isareti. Logout'ta hangi token'in
/// pasiflestirilecegini bilmek icin saklanir (uygulama yeniden acilsa bile).
class PushTokenStore {
  PushTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kRegistered = 'push.registered_fcm_token';
  static const _kKurulum = 'push.kurulum_kimligi';

  Future<String?> read() => _storage.read(key: _kRegistered);

  /// (P191-ek §1) KARARLI KURULUM KIMLIGI — cihaz basina TEK kayit icin.
  ///
  /// OLCULEN KUSUR: bir tesiste 18 kayitli cihaz vardi ve hepsi TEK
  /// kullaniciya aitti. FCM jetonu yeniden kurulumda/veri temizliginde
  /// degisir; backend tekilligi jetona bagli oldugu icin her yeni jeton
  /// YENI SATIR aciyor, eskisi "aktif" kalip her gonderimde bosuna
  /// deneniyordu. Jeton bir cihaz kimligi DEGILDIR — adrestir.
  ///
  /// DONANIM KIMLIGI KULLANILMADI (androidId/IDFV): o kalici bir
  /// izleyicidir, uygulama silinse bile kalir ve KVKK acisindan gereksiz
  /// bir veridir. Kurulum kimligi ILK ACILISTA uretilir, guvenli depoda
  /// yasar ve uygulama silinince kaybolur — bize gereken tek sey "ayni
  /// kurulum mu?" sorusunun cevabi.
  ///
  /// UUID PAKETI EKLENMEDI: 16 rastgele bayt yeter ve yeni bir bagimlilik
  /// (yeni bir surum/lisans/guvenlik yuzeyi) tek bir dize icin fazladir.
  Future<String> kurulumKimligi() async {
    final mevcut = await _storage.read(key: _kKurulum);
    if (mevcut != null && mevcut.isNotEmpty) return mevcut;
    final rastgele = Random.secure();
    final bayt = List<int>.generate(16, (_) => rastgele.nextInt(256));
    final kimlik =
        bayt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _kKurulum, value: kimlik);
    return kimlik;
  }

  Future<void> save(String token) =>
      _storage.write(key: _kRegistered, value: token);

  Future<void> clear() => _storage.delete(key: _kRegistered);
}

final pushTokenStoreProvider = Provider<PushTokenStore>((ref) {
  return PushTokenStore(ref.watch(secureStorageProvider));
});
