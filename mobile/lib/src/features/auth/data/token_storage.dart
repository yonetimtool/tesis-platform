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
  // "Beni hatirla" ON-DOLDURMA icin saklanan KIMLIK (telefon/e-posta).
  //
  // (P247 §4) PAROLA ARTIK SAKLANMAZ. Oturum 30 gun (kayan) yasadigindan
  // "beni hatirla"nin isi jetonu saklamaktir; parolayi cihazda tutmak,
  // cihazi ele geciren birine hesabin KALICI anahtarini vermekti (jeton
  // sunucudan iptal edilebilir, parola edilemez). Eski surumlerin yazdigi
  // parola ilk okumada/yazmada SILINIR (`_kSavedPassword` yalniz bunun icin).
  static const _kSavedPhone = 'auth.saved_phone';
  static const _kSavedPassword = 'auth.saved_password';

  Future<void> save(TokenPair tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  /// "Beni hatirla" bayragi: true ise acilista oturum geri yuklenmeye calisilir.
  ///
  /// (P247 §4) VARSAYILAN HATIRLA. Once bayrak yalniz parolali giriste
  /// yaziliyordu; SSO, davet, kodla giris ve tesis olusturma yollari onu
  /// HIC yazmiyordu ve bu kullanicilar uygulamayi her yeniden acista
  /// OTURUMSUZ kaliyordu — "30 gun oturum" yalniz kutuyu isaretleyen
  /// parolali kullanici icin dogruydu. Artik yalniz ACIKCA "hatirlama"
  /// denirse `'false'` yazilir; kayit yoksa hatirlanir.
  Future<void> saveRememberMe(bool value) =>
      _storage.write(key: _kRemember, value: value ? 'true' : 'false');

  Future<bool> readRememberMe() async =>
      await _storage.read(key: _kRemember) != 'false';

  /// (P170 §1) SAKLANAN KIMLIK BILGISI BU CIHAZI TERK ETMEZ.
  ///
  /// Varsayilan anahtarlik erisilebilirligi (`unlocked`) iCloud Anahtar
  /// Zinciri ile YENI BIR CIHAZA TASINIR. Bir jeton icin bunun bedeli
  /// sinirlidir (kisa omurlu, sunucudan iptal edilebilir); bir PAROLA icin
  /// degildir — yedegi geri yuklenen baska bir telefonda kullanicinin
  /// parolasi hazir beklerdi.
  ///
  /// `unlocked_this_device`: okunabilirlik ayni (yalniz cihaz kilidi
  /// aciksa), ama oge CIHAZA BAGLI kalir. Android tarafinda karsiligi
  /// zaten varsayilan: Keystore anahtari donanima bagli ve disari cikmaz.
  static const _kimlikSecenekleri = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  /// "Beni hatirla" isaretliyken cagrilir: sonraki girislerde ON-DOLDURMA icin
  /// YALNIZ kimligi saklar. [password] (P247 §4) YOK SAYILIR — imza, cagiran
  /// yerleri ve test sahtelerini kirmamak icin korunur.
  Future<void> saveCredentials({
    required String phone,
    required String password,
  }) async {
    await _storage.write(
      key: _kSavedPhone, value: phone, iOptions: _kimlikSecenekleri,
    );
    await _eskiParolayiSil();
  }

  /// Saklanan kimlik (parola HER ZAMAN bos) ya da yoksa null.
  Future<({String phone, String password})?> readCredentials() async {
    await _eskiParolayiSil();
    final phone = await _storage.read(key: _kSavedPhone);
    if (phone == null || phone.isEmpty) return null;
    return (phone: phone, password: '');
  }

  /// (P247 §4) 1.6.x ve oncesinin sakladigi parolayi temizler.
  Future<void> _eskiParolayiSil() =>
      _storage.delete(key: _kSavedPassword, iOptions: _kimlikSecenekleri);

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
