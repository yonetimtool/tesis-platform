/// JWT payload'ini IMZA DOGRULAMADAN cozer — yalnizca gosterim/istemci
/// suzme amaclidir (orn. gorev listesinde "bana atanan" vurgusu icin `sub`).
/// Yetki kararlari HER ZAMAN backend'dedir; buradaki degerlere guvenlik
/// karari baglanmaz.
library;

import 'dart:convert';

/// `header.payload.signature` bicimindeki token'in payload claim'lerini
/// dondurur. Bicim bozuksa null (cokme yok).
Map<String, dynamic>? decodeJwtClaims(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
