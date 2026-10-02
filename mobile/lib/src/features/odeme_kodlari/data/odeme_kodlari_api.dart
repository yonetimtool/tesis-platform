/// (P250 §2) Yöneticinin ödeme kodları ince istemcisi — web ile AYNI uçlar.
///
///   * `POST /users/odeme-kodlari`        — liste (eksik kodları üretir;
///                                          yeni eklenen en üstte),
///   * `POST /users/odeme-kodlari/eposta` — tek kişiye / seçilenlere e-posta.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class OdemeKoduSatiri {
  const OdemeKoduSatiri({
    required this.userId,
    required this.ad,
    required this.odemeKodu,
    this.daireNo,
    this.email,
    this.epostaDurumu,
    this.epostaEngeli,
  });

  final String userId;
  final String ad;
  final String odemeKodu;
  final String? daireNo;
  final String? email;

  /// kuyrukta | gonderildi | iletildi | geri_dondu | basarisiz |
  /// yapilandirilmadi — hiç gönderilmediyse null.
  final String? epostaDurumu;

  /// eposta_yok | eposta_kapali — gönderilemiyorsa sebebi.
  final String? epostaEngeli;

  factory OdemeKoduSatiri.fromJson(Map<String, dynamic> j) => OdemeKoduSatiri(
        userId: j['user_id'] as String,
        ad: j['ad'] as String,
        odemeKodu: j['odeme_kodu'] as String,
        daireNo: j['daire_no'] as String?,
        email: j['email'] as String?,
        epostaDurumu: j['eposta_durumu'] as String?,
        epostaEngeli: j['eposta_engeli'] as String?,
      );
}

typedef OdemeKoduGonderimSonucu = ({
  int gonderilen,
  int kuyrugaAlinan,
  int atlanan,
});

class OdemeKodlariApi {
  OdemeKodlariApi(this._dio);

  final Dio _dio;

  Future<List<OdemeKoduSatiri>> listele() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/users/odeme-kodlari',
        data: <String, dynamic>{},
      );
      return [
        for (final e in (res.data!['items'] as List))
          OdemeKoduSatiri.fromJson(e as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<OdemeKoduGonderimSonucu> gonder(List<String> userIds) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/users/odeme-kodlari/eposta',
        data: {'user_ids': userIds},
      );
      final d = res.data!;
      return (
        gonderilen: (d['gonderilen'] as num?)?.toInt() ?? 0,
        kuyrugaAlinan: (d['kuyruga_alinan'] as num?)?.toInt() ?? 0,
        atlanan: ((d['atlananlar'] as List?) ?? const []).length,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final odemeKodlariApiProvider =
    Provider<OdemeKodlariApi>((ref) => OdemeKodlariApi(ref.watch(dioProvider)));
