/// (P202) `POST /surum/kontrol` — sunucunun guncelleme karari.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/surum_karari.dart';

class SurumApi {
  SurumApi(this._dio);

  final Dio _dio;

  /// Karari sorar. HATA FIRLATMAZ — cagiran zaten "hata = engelleme yok"
  /// diyecekti; istisnayi buradan disari salmak, her cagirinin ayni
  /// `try/catch`i yazmasini gerektirirdi ve BIRI UNUTURDU.
  Future<SurumKarari> kontrol({
    required String platform,
    required String surum,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/surum/kontrol',
        data: {'platform': platform, 'surum': surum},
      );
      return SurumKarari.fromJson(res.data ?? const {});
    } catch (_) {
      // AG HATASI KULLANICIYI KILITLEMEZ (istegin KRITIK KURALI).
      // Sunucuya ulasilamiyorsa uygulama CALISMAYA DEVAM EDER: aksi
      // hâlde bir kesinti, kullanicilarin telefonunda "uygulama
      // acilmiyor" olarak gorunurdu — yani kendi altyapimizin arizasi
      // musterinin arizasina donusurdu.
      return const SurumKarari(durum: SurumDurumu.guncel);
    }
  }
}

final surumApiProvider = Provider<SurumApi>((ref) {
  return SurumApi(ref.watch(dioProvider));
});
