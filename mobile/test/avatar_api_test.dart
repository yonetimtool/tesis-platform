import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';

void main() {
  test('avatarUrlFromMe savunmaci parse', () {
    expect(avatarUrlFromMe({'avatar_url': 'https://x/y.jpg'}), 'https://x/y.jpg');
    expect(avatarUrlFromMe(const {}), isNull);
    expect(avatarUrlFromMe({'avatar_url': null}), isNull);
  });
}
