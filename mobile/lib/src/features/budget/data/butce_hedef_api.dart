import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P253 Asama 2) BUTCE HEDEFLERI — web `/finans/butce` ile ayni uclar.
///
///   * `GET  /budget/hedefler?yil=`        yazilan hedefler
///   * `POST /budget/hedefler`             yaz (ayni tur + donem = GUNCELLEME)
///   * `DELETE /budget/hedefler/{id}`      sil (muhasebe kaydi degismez)
///   * `GET  /budget/karsilastirma?yil=`   hedef / gerceklesen / sapma
class ButceHedefi {
  const ButceHedefi({
    required this.id,
    required this.yil,
    required this.kategoriId,
    required this.tutarKurus,
    this.donem,
    this.aciklama,
  });

  final String id;
  final int yil;

  /// null = YILLIK hedef; 'YYYY-MM' = o ayin hedefi.
  final String? donem;
  final String kategoriId;
  final int tutarKurus;
  final String? aciklama;

  factory ButceHedefi.fromJson(Map<String, dynamic> j) => ButceHedefi(
        id: j['id'] as String,
        yil: (j['yil'] as num).toInt(),
        donem: j['donem'] as String?,
        kategoriId: j['kategori_id'] as String,
        tutarKurus: (j['tutar_kurus'] as num).toInt(),
        aciklama: j['aciklama'] as String?,
      );
}

class ButceKarsilastirmaSatiri {
  const ButceKarsilastirmaSatiri({
    required this.ad,
    required this.gider,
    required this.hedefKurus,
    required this.gerceklesenKurus,
    required this.sapmaKurus,
    this.sapmaYuzde,
  });

  final String ad;
  final bool gider;
  final int hedefKurus;
  final int gerceklesenKurus;

  /// gerceklesen - hedef. GIDERDE pozitif = butce asildi (kotu);
  /// GELIRDE pozitif = hedefin uzerinde (iyi).
  final int sapmaKurus;
  final int? sapmaYuzde;

  /// Web `sapmaKotuMu` ile ayni kural.
  bool get kotu => gider == (sapmaKurus > 0);

  factory ButceKarsilastirmaSatiri.fromJson(Map<String, dynamic> j) => ButceKarsilastirmaSatiri(
        ad: j['ad'] as String? ?? '',
        gider: j['tip'] == 'gider',
        hedefKurus: (j['hedef_kurus'] as num?)?.toInt() ?? 0,
        gerceklesenKurus: (j['gerceklesen_kurus'] as num?)?.toInt() ?? 0,
        sapmaKurus: (j['sapma_kurus'] as num?)?.toInt() ?? 0,
        sapmaYuzde: (j['sapma_yuzde'] as num?)?.toInt(),
      );
}

class ButceKarsilastirma {
  const ButceKarsilastirma({
    required this.satirlar,
    required this.hedefGelir,
    required this.hedefGider,
    required this.gercekGelir,
    required this.gercekGider,
  });

  final List<ButceKarsilastirmaSatiri> satirlar;
  final int hedefGelir;
  final int hedefGider;
  final int gercekGelir;
  final int gercekGider;

  factory ButceKarsilastirma.fromJson(Map<String, dynamic> j) => ButceKarsilastirma(
        satirlar: [
          for (final m in (j['items'] as List? ?? const []).whereType<Map>())
            ButceKarsilastirmaSatiri.fromJson(Map<String, dynamic>.from(m)),
        ],
        hedefGelir: (j['hedef_gelir_kurus'] as num?)?.toInt() ?? 0,
        hedefGider: (j['hedef_gider_kurus'] as num?)?.toInt() ?? 0,
        gercekGelir: (j['gerceklesen_gelir_kurus'] as num?)?.toInt() ?? 0,
        gercekGider: (j['gerceklesen_gider_kurus'] as num?)?.toInt() ?? 0,
      );
}

class ButceHedefApi {
  ButceHedefApi(this._dio);

  final Dio _dio;

  Future<T> _sar<T>(Future<T> Function() is_) async {
    try {
      return await is_();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<ButceHedefi>> hedefler(int yil) => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>('/budget/hedefler',
            queryParameters: {'yil': yil});
        return [
          for (final m in (r.data?['items'] as List? ?? const []).whereType<Map>())
            ButceHedefi.fromJson(Map<String, dynamic>.from(m)),
        ];
      });

  Future<ButceHedefi> yaz({
    required int yil,
    required String kategoriId,
    required int tutarKurus,
    String? donem,
    String? aciklama,
  }) =>
      _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>('/budget/hedefler', data: {
          'yil': yil,
          'kategori_id': kategoriId,
          'tutar_kurus': tutarKurus,
          'donem': ?donem,
          'aciklama': ?aciklama,
        });
        return ButceHedefi.fromJson(r.data!);
      });

  Future<void> sil(String id) => _sar(() => _dio.delete<void>('/budget/hedefler/$id'));

  Future<ButceKarsilastirma> karsilastirma(int yil) => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>('/budget/karsilastirma',
            queryParameters: {'yil': yil});
        return ButceKarsilastirma.fromJson(r.data ?? const {});
      });
}

final butceHedefApiProvider = Provider<ButceHedefApi>(
  (ref) => ButceHedefApi(ref.watch(dioProvider)),
);
