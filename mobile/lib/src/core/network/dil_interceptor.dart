import 'package:dio/dio.dart';

/// Her istege `Accept-Language` ekler (tur 14).
///
/// NEDEN: sunucu hata metinleri artik yerellestirilmis (`backend/app/
/// hata_metinleri.py`). Sunucu dili YALNIZ bu basliktan bilir; header
/// gitmezse 7 dilin hepsinde Turkce hata doner.
///
/// DEGER **cihaz** dili degil, uygulamanin O AN cizdigi dildir: kullanici
/// uygulama icinden Arapca sectiyse cihaz Turkce olsa bile `ar` gider.
/// Dil calisma aninda degisebildigi icin baslik istek aninda okunur
/// (`dilKodu` bir geri-cagirim) — sabit header ile secim degisimi kacar.
///
/// Bicim: `ar` degil `ar, tr;q=0.8` — sunucuda cevirisi eksik bir metin
/// varsa RFC 9110 zinciri Turkce'ye duser (uygulamadaki geri-dusme ile ayni).
class DilInterceptor extends Interceptor {
  DilInterceptor({required this.dilKodu});

  /// Aktif UI dilini (ISO 639-1) donduren geri-cagirim.
  final String Function() dilKodu;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final dil = dilKodu();
    options.headers['Accept-Language'] =
        dil == 'tr' ? 'tr' : '$dil, tr;q=0.8';
    handler.next(options);
  }
}
