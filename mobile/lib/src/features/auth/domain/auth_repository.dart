import 'phone_login_result.dart';

/// Auth is mantigi icin domain sozlesmesi. Presentation katmani yalnizca bu
/// soyutlamayi bilir; HTTP/storage detaylari data katmaninda gizlidir.
abstract interface class AuthRepository {
  /// MOBIL giris: `POST /auth/login-phone` (cep telefonu + kod|parola).
  /// Tenant numaradan otomatik cozulur. Normal giriste token'lar saklanir;
  /// gecici kodla ilk giriste HICBIR sey saklanmaz — donen `setupToken` ile
  /// [setPassword] cagrilmalidir. [rememberMe] true ise "beni hatirla" bayragi
  /// kalici saklanir. Hata durumunda [ApiException] firlatir.
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  });

  /// Tenant self-signup: `POST /auth/signup` (yonetici tesis + kendi hesabini
  /// acar). Basarida donen token cifti saklanir (auto-login) ve [rememberMe]
  /// uygulanir. Hata durumunda [ApiException] firlatir.
  Future<void> signup({
    required String tenantAd,
    required String yoneticiAd,
    required String phone,
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
