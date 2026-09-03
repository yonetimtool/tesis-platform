import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/bildirim_tercihleri.dart';

/// (P183 §5) `/me/bildirim-tercihleri` ince HTTP istemcisi. PATCH KISMIDIR —
/// yalniz degisen kanal gonderilir; oteki kanallar sunucuda AYNEN kalir (iki
/// sekme acikken birinin otekini sessizce geri almasini onler — bkz. backend
/// `BildirimTercihUpdate`).
class BildirimTercihApi {
  BildirimTercihApi(this._dio);

  final Dio _dio;

  /// `GET /me/bildirim-tercihleri` — uc kanalin guncel degeri.
  Future<BildirimTercihleri> getir() async {
    try {
      final res = await _dio
          .get<Map<String, dynamic>>('/me/bildirim-tercihleri');
      return BildirimTercihleri.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /me/bildirim-tercihleri` — verilen kanal(lar)i gunceller, gunel
  /// tam durumu doner. Alan `null` ise o kanal DEGISMEZ.
  Future<BildirimTercihleri> guncelle({
    bool? eposta,
    bool? sms,
    bool? mobil,
    bool? sesli,
  }) async {
    final data = <String, dynamic>{};
    if (eposta != null) data['bildirim_eposta'] = eposta;
    if (sms != null) data['bildirim_sms'] = sms;
    if (mobil != null) data['bildirim_mobil'] = mobil;
    // (P207 §2) SES TERCIHI SUNUCUDA: Android'de bildirimin sesi
    // KANALIN ozelligidir ve kanal olusturulduktan sonra uygulama onu
    // degistiremez — "sesi kapat" ancak sunucunun BASKA BIR KANALA
    // gondermesiyle olur.
    if (sesli != null) data['bildirim_sesi'] = sesli;
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/me/bildirim-tercihleri',
        data: data,
      );
      return BildirimTercihleri.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final bildirimTercihApiProvider = Provider<BildirimTercihApi>(
  (ref) => BildirimTercihApi(ref.watch(dioProvider)),
);

/// Ayarlar ekrani acilisinda yuklenen kanal tercihleri. Guncelleme sonrasi
/// `ref.invalidate` ile tazelenir (veya controller iyimser gunceller).
final bildirimTercihProvider = FutureProvider.autoDispose<BildirimTercihleri>(
  (ref) => ref.watch(bildirimTercihApiProvider).getir(),
);
