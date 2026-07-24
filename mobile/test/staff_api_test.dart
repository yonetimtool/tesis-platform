import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';

void main() {
  test('StaffMember avatar_url savunmaci parse', () {
    final s = StaffMember.fromJson(const {
      'id': 'u1', 'ad': 'Guard A', 'role': 'security',
      'is_active': true, 'avatar_url': 'https://x/a.jpg',
    });
    expect(s.avatarUrl, 'https://x/a.jpg');
    expect(
      StaffMember.fromJson(const {
        'id': 'u2', 'ad': 'B', 'role': 'security', 'is_active': true,
      }).avatarUrl,
      isNull,
    );
  });

  test('avatarUrlFromUsers SAF parse', () {
    expect(avatarUrlFromUsers({'avatar_url': 'https://x/y.jpg'}),
        'https://x/y.jpg');
    expect(avatarUrlFromUsers(const {}), isNull);
  });
}
