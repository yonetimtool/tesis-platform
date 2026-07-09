/// Auth is mantigi icin domain sozlesmesi. Presentation katmani yalnizca bu
/// soyutlamayi bilir; HTTP/storage detaylari data katmaninda gizlidir.
abstract interface class AuthRepository {
  /// `POST /auth/login` cagirir ve donen token cifti'ni guvenli depoya yazar.
  /// [rememberMe] true ise "beni hatirla" bayragi da kalici saklanir; sonraki
  /// acilista [restoreSession] oturumu geri yuklemeye calisir.
  /// Hata durumunda [ApiException] firlatir.
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
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
