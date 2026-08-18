import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/kvkk_models.dart';

/// `/kvkk/*` + `/me/pazarlama-tercihleri` ince istemcisi (P36).
class KvkkApi {
  KvkkApi(this._dio);

  final Dio _dio;

  Future<KvkkDurum> durum({KvkkTur tur = KvkkTur.aydinlatma}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/kvkk/durum',
        queryParameters: {'tur': tur.kod},
      );
      return KvkkDurum.fromJson(r.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<KvkkMetin> metin({KvkkTur tur = KvkkTur.aydinlatma}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/kvkk/metin',
        queryParameters: {'tur': tur.kod},
      );
      return KvkkMetin.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Onaylanan SURUM govdede tasinir: ekranda GORULEN surum bildirilir.
  /// Arada metin degistiyse sunucu 409 doner ve istemci yeni metni gosterir.
  Future<KvkkDurum> onayla(int surum, {KvkkTur tur = KvkkTur.aydinlatma}) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/kvkk/onay',
        // TUR DE GONDERILIR: sunucu onayi tur basina tutuyor ve
        // gondermeseydik her onay `aydinlatma`ya yazilirdi — kullanici
        // gizlilik politikasini onayladi sanip aydinlatma metnini
        // onaylamis olurdu.
        data: {'tur': tur.kod, 'surum': surum},
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

/// Aydinlatma metni — ONAY KAPISININ kullandigi saglayici (tur sabit).
final kvkkMetinProvider = FutureProvider<KvkkMetin>(
  (ref) => ref.watch(kvkkApiProvider).metin(),
);

/// (P168 §5) TUR BASINA metin — "Yasal Metinler" ekrani bunu kullanir.
final kvkkTurMetinProvider =
    FutureProvider.autoDispose.family<KvkkMetin, KvkkTur>(
  (ref, tur) => ref.watch(kvkkApiProvider).metin(tur: tur),
);

/// (P168 §5) TUR BASINA onay durumu — kullanici hangi surumu ne zaman
/// onayladigini gorebilmeli (brief: "onay gecmisini gorebilsin").
final kvkkTurDurumProvider =
    FutureProvider.autoDispose.family<KvkkDurum, KvkkTur>(
  (ref, tur) => ref.watch(kvkkApiProvider).durum(tur: tur),
);

final pazarlamaTercihProvider = FutureProvider<PazarlamaTercihleri>(
  (ref) => ref.watch(kvkkApiProvider).tercihler(),
);
