import 'phone_login_result.dart';

/// Auth is mantigi icin domain sozlesmesi. Presentation katmani yalnizca bu
/// soyutlamayi bilir; HTTP/storage detaylari data katmaninda gizlidir.
abstract interface class AuthRepository {
  /// MOBIL giris: `POST /auth/login-phone` (cep telefonu + kod|parola).
  /// Tenant numaradan otomatik cozulur. Normal giriste token'lar saklanir;
  /// gecici kodla ilk giriste HICBIR sey saklanmaz — donen `setupToken` ile
  /// [setPassword] cagrilmalidir. [rememberMe] true ise "beni hatirla" bayragi
  /// kalici saklanir. Hata durumunda [ApiException] firlatir.
  /// (P149) Parolasiz giris: numaraya kod gonder.
  Future<void> girisKoduIste(String telefon);

  /// (P149) Kod dogruysa oturumu ACAR ve token'lari saklar.
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe,
  });

  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  });

  /// Ilk giristeki zorunlu kalici parola belirleme: `POST /auth/set-password`.
  /// Basarida donen token cifti saklanir (oturum acilir) ve [rememberMe]
  /// tercihi uygulanir. [phone] verilir + [rememberMe] true ise ON-DOLDURMA
  /// icin telefon + yeni parola saklanir. Hata durumunda [ApiException] firlatir.
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  });

  /// "Beni hatirla" isaretliyken saklanan giris bilgileri (telefon + parola);
  /// login ekrani acilista alanlari bununla ON-DOLDURUR. Yoksa null.
  Future<({String phone, String password})?> readSavedCredentials();

  /// (P155 §7) Davetle gelen kullanici PAROLA belirler (SMS YOK) ve oturum
  /// acilir. Donen jetonlar saklanir.
  Future<void> davetParola({
    required String jeton,
    String? ad,
    required String newPassword,
  });

  /// (P155 §7) Davetle gelen kullanici SOSYAL hesabini baglar (SMS YOK) ve
  /// oturum acilir.
  Future<void> davetSosyal({
    required String jeton,
    required String baglamaJetonu,
    String? ad,
  });

  /// Acilista saklanan oturumu geri yuklemeye calisir: "beni hatirla" bayragi
  /// + refresh token varsa `POST /auth/refresh` denenir. Basarili → true
  /// (login ekrani atlanir). Bayrak yoksa ya da refresh kurtarilamazsa →
  /// false (login ekrani). Asla hata firlatmaz.
  Future<bool> restoreSession();

  /// Saklanan token'lari ve "beni hatirla" bayragini siler (logout).
  Future<void> logout();
}
