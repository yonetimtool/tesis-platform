/// Auth is mantigi icin domain sozlesmesi. Presentation katmani yalnizca bu
/// soyutlamayi bilir; HTTP/storage detaylari data katmaninda gizlidir.
abstract interface class AuthRepository {
  /// `POST /auth/login` cagirir ve donen token cifti'ni guvenli depoya yazar.
  /// Hata durumunda [ApiException] firlatir.
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
  });

  /// Cihazda saklanmis bir oturum (refresh token) var mi? Acilista login
  /// ekranini atlayip atlamayacagimizi belirler.
  Future<bool> hasSession();

  /// Saklanan token'lari siler (logout).
  Future<void> logout();
}
