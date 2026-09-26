import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P248 §1-kamera) GECMIS KAYIT (NVR) — `/cameras/{id}/kayit/*` istemcisi.
///
/// P213'te yalniz web'deydi; P248'de guvenlik amiri web'e GIREMEZ
/// (mobil-yalniz), amirin gecmis kaydi izleyebilmesi icin mobile geldi.
/// SUNUCU DEGISMEDI: rol kapisi (`admin/yonetici/guvenlik_amiri`), 24
/// saat pencere siniri ve her arama/izleme icin denetim satiri sunucuda.
/// Istemcideki 24 saat denetimi YALNIZ kullaniciyi bosuna bekletmemek
/// icindir — yetki/sinir sunucunun isi.
class KayitAraligi {
  const KayitAraligi(this.bas, this.bit);

  final DateTime bas;
  final DateTime bit;

  factory KayitAraligi.fromJson(Map<String, dynamic> j) => KayitAraligi(
        DateTime.parse(j['bas'] as String),
        DateTime.parse(j['bit'] as String),
      );
}

class KayitAramaSonucu {
  const KayitAramaSonucu({required this.aramaDestekli, required this.araliklar});

  /// `false` "KAYIT YOK" DEMEK DEGILDIR: `sablon` saglayicisi oynatabilir
  /// ama arayamaz. Ekran ikisini AYRI mesajla gosterir (web ile ayni).
  final bool aramaDestekli;
  final List<KayitAraligi> araliklar;

  factory KayitAramaSonucu.fromJson(Map<String, dynamic> j) => KayitAramaSonucu(
        aramaDestekli: j['arama_destekli'] as bool? ?? false,
        araliklar: [
          for (final a in (j['araliklar'] as List?) ?? const [])
            if (a is Map) KayitAraligi.fromJson(Map<String, dynamic>.from(a)),
        ],
      );
}

class KameraKayitApi {
  KameraKayitApi(this._dio);
  final Dio _dio;

  /// Zamanlar sunucuya UTC ISO olarak gider: kullanici yerel saati secer,
  /// cihaz dilimi burada cozulur (web `isoYap` ile ayni anlam).
  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  /// `GET /cameras/{id}/kayit/araliklar?bas=&bit=`
  Future<KayitAramaSonucu> araliklar(
    String kameraId,
    DateTime bas,
    DateTime bit,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/cameras/$kameraId/kayit/araliklar',
        queryParameters: {'bas': _iso(bas), 'bit': _iso(bit)},
      );
      return KayitAramaSonucu.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /cameras/{id}/kayit/oynat` -> API'ye GORELI HLS yolu
  /// (`/cameras/{id}/kayit/<yol>/index.m3u8`). Oynatici bu yolu
  /// `Authorization: Bearer` basligiyla acar (bkz. oynatici ekrani).
  Future<String> oynat(String kameraId, DateTime bas, DateTime bit) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/cameras/$kameraId/kayit/oynat',
        data: {'bas': _iso(bas), 'bit': _iso(bit)},
      );
      return (res.data?['yol'] as String?) ?? '';
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final kameraKayitApiProvider = Provider<KameraKayitApi>((ref) {
  return KameraKayitApi(ref.watch(dioProvider));
});
