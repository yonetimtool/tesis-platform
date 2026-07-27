import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_controller.dart';
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
  // DIL DEGISIMI -> cihazi YENIDEN kaydet (tur 16). Push metni sunucuda,
  // GONDERIM aninda uretilir ve dili `user_device.dil`den okur; istek
  // basligi (Accept-Language) o anda yoktur. Yeniden kayit yapilmazsa
  // kullanici dili degistirse bile bildirimler ESKI dilde gelmeye devam
  // ederdi. Kayit idempotent upsert'tir (ayni token -> ayni satir).
  // Dinlenen sey SECIM'dir (`localeControllerProvider`), turetilmis
  // `aktifDilKoduProvider` degil: turetilmis Provider yalniz OKUNDUGUNDA
  // yeniden hesaplanir, dolayisiyla ona kurulan dinleyici sessizce hic
  // tetiklenmeyebilir. Cihaz dili zaten calisma aninda degismez.
  ref.listen(localeControllerProvider, (onceki, yeni) {
    if (onceki == yeni) return;
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      return; // oturum yokken POST /devices 401 verir; login zaten kaydeder
    }
    unawaited(ref.read(pushRegistrarProvider.notifier).registerCurrentToken());
  });

  // Kurulum aninda oturum zaten aciksa (orn. bu provider auth restore'dan
  // sonra canlanirsa) gecis olayi kacmis olabilir — mevcut durumu da isle.
  if (ref.read(authControllerProvider).status == AuthStatus.authenticated) {
    Future.microtask(
      () => ref.read(pushRegistrarProvider.notifier).registerCurrentToken(),
    );
  }
});
