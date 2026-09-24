/// (P247 §7) GORUNUM MODU <-> HESAP (`app_user.ui_gorunum`, goc 0147).
///
/// Neden var: bkz. [GorunumModuController] ustundeki "HESAPLA ESITLENIR"
/// notu. Burada yalniz TEL var — iki uc ve esitlemeyi tetikleyen dinleyici.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../network/dio_provider.dart';
import 'gorunum_modu.dart';

/// `GET /me` (`ui_gorunum`) ve `PATCH /me/gorunum` — web'in kullandigi
/// AYNI iki uc (P243 §4). Yeni uc YOK.
class GorunumSunucu {
  GorunumSunucu(this._dio);

  final Dio _dio;

  /// Hesaptaki mod; ag/sunucu hatasinda `null` (yerel deger korunur).
  Future<GorunumModu?> oku() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me');
      final ham = res.data?['ui_gorunum'];
      // Alan YOKSA (P243 oncesi sunucu) hic karar verme: bilinmeyen bir
      // degeri "standart" saymak, yerel "buyuk"u sessizce ezerdi.
      if (ham is! String) return null;
      return gorunumModuCoz(ham);
    } catch (_) {
      return null;
    }
  }

  /// Basariliysa `true`. Hata YUTULUR: gorunum kozmetik bir tercih,
  /// kullaniciya hata gostermek yerine bir sonraki oturumda yeniden
  /// gonderilir (bkz. `esitlikAnahtari`).
  Future<bool> yaz(GorunumModu mod) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/me/gorunum',
        data: {'gorunum': mod.kod},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final gorunumSunucuProvider = Provider<GorunumSunucu>(
  (ref) => GorunumSunucu(ref.watch(dioProvider)),
);

/// Oturum acilinca (giris ya da kayitli oturumla soguk acilis) hesapla
/// esitler. `pushSetupProvider` ile AYNI desen; kok widget izler.
final gorunumEsitlemeProvider = Provider<void>((ref) {
  ref.listen(authControllerProvider.select((s) => s.status), (onceki, yeni) {
    if (yeni == AuthStatus.authenticated && onceki != yeni) {
      unawaited(ref.read(gorunumModuProvider.notifier).sunucuylaEsitle());
    }
  });
  // Provider oturum ZATEN acikken canlanirsa gecis olayi kacmistir.
  if (ref.read(authControllerProvider).status == AuthStatus.authenticated) {
    unawaited(ref.read(gorunumModuProvider.notifier).sunucuylaEsitle());
  }
});
