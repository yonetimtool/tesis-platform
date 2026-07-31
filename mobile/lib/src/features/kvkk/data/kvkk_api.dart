import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/kvkk_models.dart';

/// `/kvkk/*` + `/me/pazarlama-tercihleri` ince istemcisi (P36).
class KvkkApi {
  KvkkApi(this._dio);

  final Dio _dio;

  Future<KvkkDurum> durum() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/kvkk/durum');
      return KvkkDurum.fromJson(r.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<KvkkMetin> metin() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/kvkk/metin');
      return KvkkMetin.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Onaylanan SURUM govdede tasinir: ekranda GORULEN surum bildirilir.
  /// Arada metin degistiyse sunucu 409 doner ve istemci yeni metni gosterir.
  Future<KvkkDurum> onayla(int surum) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/kvkk/onay',
        data: {'surum': surum},
      );
      return KvkkDurum.fromJson(r.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PazarlamaTercihleri> tercihler() async {
    try {
      final r =
          await _dio.get<Map<String, dynamic>>('/me/pazarlama-tercihleri');
      return PazarlamaTercihleri.fromJson(r.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// KISMI guncelleme: gonderilmeyen kanal DEGISMEZ (kanallar bagimsiz).
  Future<PazarlamaTercihleri> tercihGuncelle(Map<String, bool> degisen) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/me/pazarlama-tercihleri',
        data: degisen,
      );
      return PazarlamaTercihleri.fromJson(r.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final kvkkApiProvider = Provider<KvkkApi>((ref) => KvkkApi(ref.watch(dioProvider)));

/// Onay kapisinin girdisi. HATA = KAPI ACILMAZ (bkz. KvkkDurum.kapaliVarsayilan).
final kvkkDurumProvider = FutureProvider<KvkkDurum>((ref) async {
  try {
    return await ref.watch(kvkkApiProvider).durum();
  } catch (_) {
    return KvkkDurum.kapaliVarsayilan;
  }
});

final kvkkMetinProvider = FutureProvider<KvkkMetin>(
  (ref) => ref.watch(kvkkApiProvider).metin(),
);

final pazarlamaTercihProvider = FutureProvider<PazarlamaTercihleri>(
  (ref) => ref.watch(kvkkApiProvider).tercihler(),
);
