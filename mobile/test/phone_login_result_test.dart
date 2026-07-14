import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';

void main() {
  group('PhoneLoginResult.fromJson', () {
    test('normal giris: token cifti dolu, kurulum gerekmez', () {
      final result = PhoneLoginResult.fromJson({
        'password_setup_required': false,
        'setup_token': null,
        'access_token': 'a.b.c',
        'refresh_token': 'r.e.f',
        'token_type': 'Bearer',
        'expires_in': 900,
      });

      expect(result.passwordSetupRequired, isFalse);
      expect(result.setupToken, isNull);
      expect(result.tokens, isNotNull);
      expect(result.tokens!.accessToken, 'a.b.c');
      expect(result.tokens!.refreshToken, 'r.e.f');
    });

    test('ilk giris (gecici kod): setup_token dolu, token cifti yok', () {
      final result = PhoneLoginResult.fromJson({
        'password_setup_required': true,
        'setup_token': 'setup.jwt.token',
      });

      expect(result.passwordSetupRequired, isTrue);
      expect(result.setupToken, 'setup.jwt.token');
      expect(result.tokens, isNull);
    });
  });
}
