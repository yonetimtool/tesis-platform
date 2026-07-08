import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/jwt_claims.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.imza';
}

void main() {
  test('gecerli token: sub ve role okunur (imza DOGRULANMAZ — yalnizca '
      'gosterim amacli)', () {
    final claims = decodeJwtClaims(
      _fakeJwt({'sub': 'user-1', 'role': 'tesis_gorevlisi', 'type': 'access'}),
    );
    expect(claims, isNotNull);
    expect(claims!['sub'], 'user-1');
    expect(claims['role'], 'tesis_gorevlisi');
  });

  test('base64url padding eksikligi tolere edilir', () {
    // 1 karakterlik payload farki padding ihtiyacini degistirir.
    final claims = decodeJwtClaims(_fakeJwt({'sub': 'u'}));
    expect(claims!['sub'], 'u');
  });

  test('bozuk token null doner (cokme yok)', () {
    expect(decodeJwtClaims('sacma'), isNull);
    expect(decodeJwtClaims('a.b'), isNull);
    expect(decodeJwtClaims('a.!!!.c'), isNull);
    expect(decodeJwtClaims(''), isNull);
  });
}
