import 'resident_login_result.dart';

/// Auth is mantigi icin domain sozlesmesi. Presentation katmani yalnizca bu
/// soyutlamayi bilir; HTTP/storage detaylari data katmaninda gizlidir.
abstract interface class AuthRepository {
  /// PERSONEL girisi: `POST /auth/login` cagirir ve donen token cifti'ni
  /// guvenli depoya yazar. [rememberMe] true ise "beni hatirla" bayragi da
  /// kalici saklanir; sonraki acilista [restoreSession] oturumu geri
  /// yuklemeye calisir. Hata durumunda [ApiException] firlatir.
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  });

  /// SAKIN girisi: `POST /auth/login-resident` (daire no + kod|parola).
  /// Normal giriste token'lar saklanir (personel girisiyle ayni sekilde);
  /// gecici kodla ilk giriste HICBIR sey saklanmaz — donen `setupToken` ile
  /// [setPassword] cagrilmalidir. Hata durumunda [ApiException] firlatir.
  Future<ResidentLoginResult> loginResident({
    required String tenantSlug,
    required String unitNo,
    required String password,
    bool rememberMe = false,
  });

  /// Ilk giristeki zorunlu kalici parola belirleme: `POST /auth/set-password`.
  /// Basarida donen token cifti saklanir (oturum acilir) ve [rememberMe]
  /// tercihi uygulanir. Hata durumunda [ApiException] firlatir.
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
  });

  /// Acilista saklanan oturumu geri yuklemeye calisir: "beni hatirla" bayragi
  /// + refresh token varsa `POST /auth/refresh` denenir. Basarili → true
  /// (login ekrani atlanir). Bayrak yoksa ya da refresh kurtarilamazsa →
  /// false (login ekrani). Asla hata firlatmaz.
  Future<bool> restoreSession();

  /// Saklanan token'lari ve "beni hatirla" bayragini siler (logout).
  Future<void> logout();
}
