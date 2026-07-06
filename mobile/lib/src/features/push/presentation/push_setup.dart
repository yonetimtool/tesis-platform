import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import 'push_registrar.dart';

/// Push otomatik kayit tetikleyicisi. Uygulama kokunde watch edilir;
/// login/oturum-geri-yukleme sonrasi FCM token kaydini baslatir.
///
/// [PushRegistrar]'in kendisi auth'a bagimli DEGILDIR (AuthController
/// logout'ta registrar'i cagirdigi icin ters bagimlilik provider dongusu
/// yaratirdi); auth→push kopru bilerek bu ayri provider'da.
final pushSetupProvider = Provider<void>((ref) {
  ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
    if (next == AuthStatus.authenticated) {
      unawaited(ref.read(pushRegistrarProvider.notifier).registerCurrentToken());
    }
  });
  // Kurulum aninda oturum zaten aciksa (orn. bu provider auth restore'dan
  // sonra canlanirsa) gecis olayi kacmis olabilir — mevcut durumu da isle.
  if (ref.read(authControllerProvider).status == AuthStatus.authenticated) {
    Future.microtask(
      () => ref.read(pushRegistrarProvider.notifier).registerCurrentToken(),
    );
  }
});
