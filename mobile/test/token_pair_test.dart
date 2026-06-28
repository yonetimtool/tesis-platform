import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';

void main() {
  group('TokenPair.fromJson', () {
    test('TokenPair semasini birebir cozer', () {
      final tokens = TokenPair.fromJson({
        'access_token': 'a.b.c',
        'refresh_token': 'r.e.f',
        'token_type': 'Bearer',
        'expires_in': 900,
      });

      expect(tokens.accessToken, 'a.b.c');
      expect(tokens.refreshToken, 'r.e.f');
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.expiresIn, 900);
    });

    test('eksik token_type/expires_in icin makul varsayilanlar kullanir', () {
      final tokens = TokenPair.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
      });

      expect(tokens.tokenType, 'Bearer');
      expect(tokens.expiresIn, 0);
    });
  });
}
