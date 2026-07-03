import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/jwt_claims.dart';
import '../presentation/auth_controller.dart';
import 'token_storage.dart';

/// Oturumdaki kullanicinin id'si (JWT `sub` claim'i) — yalnizca GOSTERIM ve
/// istemci tarafi suzme icindir (orn. gorev listesinde "bana atanan"
/// vurgusu). Yetki kararlari backend'dedir. Login/logout'ta auth durumu
/// degistigi icin yeniden hesaplanir.
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  // Oturum degisimlerinde (login/logout/expire) cache'i tazele.
  ref.watch(authControllerProvider.select((s) => s.status));
  final token = await ref.watch(tokenStorageProvider).readAccessToken();
  if (token == null) return null;
  return decodeJwtClaims(token)?['sub'] as String?;
});
