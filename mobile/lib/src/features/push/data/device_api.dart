import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// `/devices` endpoint'lerinin ince HTTP istemcisi (sozlesme: DeviceRegister).
/// Backend idempotent upsert yapar — ayni token'i her acilista gondermek
/// guvenlidir.
class DeviceApi {
  DeviceApi(this._dio);

  final Dio _dio;

  /// `POST /devices` — kendi cihazinin FCM token'ini kaydeder (201; ayni
  /// token tekrar gonderilirse gunceller + aktiflestirir).
  /// [dil] CIHAZIN UI dilidir: push metni sunucuda GONDERIM aninda bu dilde
  /// uretilir (tur 16). Push asenkron oldugu icin `Accept-Language` basligi
  /// o anda YOKTUR — dil cihaz kaydinda saklanmak zorundadir.
  /// [cihazKimligi] (P191-ek §1) KARARLI KURULUM KIMLIGI. Verilirse sunucu
  /// AYNI cihazin onceki jetonlarini pasiflestirir ve kayit COGALMAZ.
  /// OPSIYONEL: alani gondermeyen eski surumler calismaya devam eder
  /// (sunucuda kolon nullable).
  /// [uygulamaSurum] (P238) Cihazdaki uygulama surumu — YALNIZ VERI
  /// TOPLAMA. Bugun sunucuda hicbir karara girmiyor; 1.5.0'da "asgari
  /// surum yukseltilince eski surumdeki cihazlara tek seferlik bildirim"
  /// hedeflemesi bunu okuyacak. BUGUN gondermeye baslamamizin sebebi:
  /// bir cihaz surumunu ancak O ALANI GONDEREN bir yapimi calistirdiginda
  /// bildirir; bugun baslamazsak 1.5.0'da 1.4.x istemciler de gorunmez
  /// olur ve ayni sorun bir tur sonra tekrarlanir.
  Future<void> register({
    required String fcmToken,
    required String platform,
    required String dil,
    String? cihazKimligi,
    String? uygulamaSurum,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/devices',
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
          'dil': dil,
          // Null ise anahtar HIC gonderilmez (sunucu 'kimlik yok' der,
          // bos dize DEMEZ): `?` isaretci null-aware oge sozdizimi.
          'cihaz_kimligi': ?cihazKimligi,
          // Null ise anahtar HIC gonderilmez: sunucu "gonderilmedi" ile
          // "bos" arasindaki farki kullaniyor (gonderilmeyen alan mevcut
          // degeri KORUR, bos dize onu SILERDI).
          'uygulama_surum': ?uygulamaSurum,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /devices/{fcm_token}` — token'i pasiflestirir (logout).
  /// 404 (zaten yok/pasif) basari sayilir — hedef duruma zaten ulasilmis.
  Future<void> unregister(String fcmToken) async {
    try {
      await _dio.delete<void>('/devices/${Uri.encodeComponent(fcmToken)}');
    } on DioException catch (e) {
      final apiError = ApiException.fromDio(e);
      if (apiError.statusCode == 404) return;
      throw apiError;
    }
  }
}

final deviceApiProvider = Provider<DeviceApi>((ref) {
  return DeviceApi(ref.watch(dioProvider));
});
