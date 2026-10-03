import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/rapor_motoru_models.dart';

/// (P253 Asama 2) RAPOR MOTORU istemcisi — web `/raporlar` sayfasinin
/// kullandigi uclarin AYNISI:
///
///   * `GET  /raporlar/katalog`               -> kategori + alanlar + agir
///   * `POST /raporlar/{kod}?bicim=tablo`     -> "Goster" (JSON)
///   * `POST /raporlar/{kod}?bicim=excel|pdf` -> dosya baytlari (hafif rapor)
///   * `POST /raporlar/{kod}/kuyruk?bicim=..` -> agir rapor KUYRUGA
///   * `GET  /raporlar/isler`                 -> isteyenin isleri
///   * `GET  /raporlar/isler/{id}/indir`      -> kisa omurlu baglanti; dosya
///     depodan (presign) ayri bir Dio ile iner (yetki basligi TASINMAZ).
///
/// Ayrica salt okuma icra listesi ve rapor formundaki secim kutularinin
/// kaynaklari (web `components/finans/ortak.ts` ile ayni uclar).
class RaporMotoruApi {
  RaporMotoruApi(this._dio, {Dio? depoDio}) : _depoDio = depoDio ?? Dio();

  final Dio _dio;
  final Dio _depoDio;

  Future<T> _sar<T>(Future<T> Function() is_) async {
    try {
      return await is_();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<RaporKatalog> katalog() => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>('/raporlar/katalog');
        return RaporKatalog.fromJson(r.data ?? const {});
      });

  Future<RaporTablo> goster(String kod, Map<String, dynamic> govde) => _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/raporlar/$kod',
          queryParameters: {'bicim': 'tablo'},
          data: govde,
        );
        return RaporTablo.fromJson(r.data ?? const {});
      });

  /// Hafif raporun Excel/PDF ciktisi. Dosya adi SUNUCUDAN
  /// (`Content-Disposition`); yoksa `kod.uzanti`.
  Future<({Uint8List baytlar, String dosyaAdi})> dosya(
    String kod,
    String bicim,
    Map<String, dynamic> govde,
  ) =>
      _sar(() async {
        final r = await _dio.post<List<int>>(
          '/raporlar/$kod',
          queryParameters: {'bicim': bicim},
          data: govde,
          options: Options(responseType: ResponseType.bytes),
        );
        final cd = r.headers.value('content-disposition') ?? '';
        final ad = RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd)?.group(1);
        return (
          baytlar: Uint8List.fromList(r.data ?? const []),
          dosyaAdi: ad ?? '$kod.${bicim == 'excel' ? 'xlsx' : 'pdf'}',
        );
      });

  Future<RaporIsi> kuyruga(String kod, String bicim, Map<String, dynamic> govde) =>
      _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/raporlar/$kod/kuyruk',
          queryParameters: {'bicim': bicim},
          data: govde,
        );
        return RaporIsi.fromJson(r.data ?? const {});
      });

  Future<List<RaporIsi>> isler() => _sar(() async {
        final r = await _dio.get<List<dynamic>>('/raporlar/isler');
        return [
          for (final m in r.data ?? const [])
            if (m is Map) RaporIsi.fromJson(Map<String, dynamic>.from(m)),
        ];
      });

  /// Hazir isin dosyasi: once kisa omurlu baglanti, sonra depodan baytlar.
  Future<({Uint8List baytlar, String dosyaAdi})> isIndir(RaporIsi is_) => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>('/raporlar/isler/${is_.id}/indir');
        final url = r.data?['url'] as String? ?? '';
        final ad = r.data?['dosya_adi'] as String? ?? is_.dosyaAdi ?? '${is_.kod}.${is_.bicim}';
        final d = await _depoDio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        return (baytlar: Uint8List.fromList(d.data ?? const []), dosyaAdi: ad);
      });

  Future<List<IcraDosyasi>> icraDosyalari({String? durum}) => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/finans/icra-dosyalari',
          queryParameters: {'durum': ?durum, 'limit': 200},
        );
        return [
          for (final m in (r.data?['items'] as List? ?? const []))
            if (m is Map) IcraDosyasi.fromJson(Map<String, dynamic>.from(m)),
        ];
      });

  /// Gorev gecmisi (web `/reports/tasks` CSV'sinin kaynagi): TUM sayfalar.
  /// Ust sinir: 5000 satir — web `fetchAllPaged` ile ayni mertebe.
  /// (P253 A2) `kesildi`: sunucuda daha fazla satir var ama sinira
  /// takildi — rapor EKSIK; ekran bunu soyler (web `raporKesildi` gibi).
  Future<({List<Map<String, dynamic>> satirlar, bool kesildi})> gorevGecmisi({
    required DateTime baslangic,
    required DateTime bitis,
  }) =>
      _sar(() async {
        const sayfa = 200;
        const ustSinir = 5000;
        final out = <Map<String, dynamic>>[];
        num? sunucuToplami;
        var sonSayfaDolu = false;
        for (var offset = 0; offset < ustSinir; offset += sayfa) {
          final r = await _dio.get<Map<String, dynamic>>(
            '/task-completions',
            queryParameters: {
              'baslangic': baslangic.toUtc().toIso8601String(),
              'bitis': bitis.toUtc().toIso8601String(),
              'limit': sayfa,
              'offset': offset,
            },
          );
          final items = [
            for (final m in (r.data?['items'] as List? ?? const []))
              if (m is Map) Map<String, dynamic>.from(m),
          ];
          out.addAll(items);
          final toplam = (r.data?['meta'] as Map?)?['total'] as num?;
          sunucuToplami = toplam ?? sunucuToplami;
          sonSayfaDolu = items.length == sayfa;
          if (items.length < sayfa || (toplam != null && out.length >= toplam)) {
            sonSayfaDolu = false;
            break;
          }
        }
        final kesildi = sunucuToplami != null ? out.length < sunucuToplami : sonSayfaDolu;
        return (satirlar: out, kesildi: kesildi);
      });

  // ---------------- secim kutularinin kaynaklari ------------------------- #
  // Rol izni yoksa (orn. denetci `/users` goremez) sunucu 403 doner; form
  // o alani yalniz "Tumu" secenegiyle cizer — web ile ayni davranis.
  List<SecimOgesi> _ogeler(Response<Map<String, dynamic>> r, String Function(Map) ad) => [
        for (final m in (r.data?['items'] as List? ?? const []))
          if (m is Map) SecimOgesi('${m['id']}', ad(m)),
      ];

  Future<List<SecimOgesi>> kasalar() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/kasalar', queryParameters: {'limit': 200}),
      (m) => '${m['ad']}'));

  Future<List<SecimOgesi>> firmalar() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/firmalar', queryParameters: {'limit': 200}),
      (m) => '${m['ad']}'));

  Future<List<SecimOgesi>> kisiler() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/users', queryParameters: {'limit': 500}),
      (m) => '${m['ad']}'));

  Future<List<SecimOgesi>> daireler() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/units', queryParameters: {'limit': 500}),
      (m) => [m['blok'], m['no']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')));

  Future<List<SecimOgesi>> tanimlar() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/gelir-gider-tanimlari', queryParameters: {'limit': 200}),
      (m) => '${m['ad']}'));

  Future<List<SecimOgesi>> personeller() => _sar(() async => _ogeler(
      await _dio.get<Map<String, dynamic>>('/personel-kayitlari', queryParameters: {'limit': 200}),
      (m) => '${m['ad']}'));

  Future<List<SecimOgesi>> secenekler(AlanTuru tur) => switch (tur) {
        AlanTuru.kasa => kasalar(),
        AlanTuru.firma => firmalar(),
        AlanTuru.kisi => kisiler(),
        AlanTuru.daire => daireler(),
        AlanTuru.tanim || AlanTuru.tanimCoklu => tanimlar(),
        AlanTuru.personel => personeller(),
        _ => Future.value(const <SecimOgesi>[]),
      };
}

final raporMotoruApiProvider = Provider<RaporMotoruApi>(
  (ref) => RaporMotoruApi(ref.watch(dioProvider)),
);
