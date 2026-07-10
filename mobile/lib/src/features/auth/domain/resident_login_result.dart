import 'token_pair.dart';

/// `POST /auth/login-resident` yaniti (openapi ResidentLoginResponse).
///
/// Iki durum tasir:
///   * Normal giris: [passwordSetupRequired] false, [tokens] dolu.
///   * Gecici kodla ILK giris: [passwordSetupRequired] true, [setupToken]
///     dolu (oturum token'i YOK) — parola belirleme zorunlu.
class ResidentLoginResult {
  const ResidentLoginResult({
    required this.passwordSetupRequired,
    this.setupToken,
    this.tokens,
  });

  final bool passwordSetupRequired;
  final String? setupToken;
  final TokenPair? tokens;

  factory ResidentLoginResult.fromJson(Map<String, dynamic> json) {
    final setupRequired = json['password_setup_required'] == true;
    return ResidentLoginResult(
      passwordSetupRequired: setupRequired,
      setupToken: json['setup_token'] as String?,
      tokens: setupRequired ? null : TokenPair.fromJson(json),
    );
  }
}
