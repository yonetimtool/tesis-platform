/// Testler icin IMZASIZ sahte JWT: `header.payload.sig`. Istemci token'i
/// yalnizca claim okumak icin cozer (imza dogrulamaz — bkz. jwt_claims.dart),
/// bu yuzden gercek imzaya gerek yoktur.
library;

import 'dart:convert';

String sahteJwt(Map<String, dynamic> claims) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(claims)}.imza';
}
