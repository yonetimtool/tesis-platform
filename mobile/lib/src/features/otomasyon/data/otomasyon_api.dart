/// (P250 §9) OTOMASYON KURALLARI — web `KurallarKarti` ile AYNI uçlar.
///
///   * `GET/POST/PATCH/DELETE /aidat-planlari` — dairelere borç yazan kural,
///   * `POST /aidat-planlari/onizleme`          — KAYDETMEDEN "bugün çalışsaydı",
///   * `POST /aidat-planlari/{id}/ertele`       — bu ayı atla,
///   * `GET/POST/PATCH/DELETE /duzenli-giderler` — site adına ödeme kaydı,
///   * `GET/PATCH /borclandirma/gecikme-ayari`  — gecikme faizi aç/kapat,
///   * `GET /borclandirma/gecikme-faizi/onizleme`, `GET /hatirlatma-ayari/onizleme`,
///   * `GET /otomasyon/son-calismalar`          — kural başına son çalışma.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class PlanKurali {
  const PlanKurali({
    required this.id,
    required this.ad,
    required this.dagitim,
    required this.tutarKurus,
    required this.toplamTutarKurus,
    required this.gun,
    required this.vadeGun,
    required this.aktif,
    this.ertelenenDonem,
  });

  final String id;
  final String ad;
  final String dagitim;
  final int? tutarKurus;
  final int? toplamTutarKurus;
  final int gun;
  final int vadeGun;
  final bool aktif;
  final String? ertelenenDonem;

  factory PlanKurali.fromJson(Map<String, dynamic> j) => PlanKurali(
    id: j['id'] as String,
    ad: (j['ad'] as String?) ?? '',
    dagitim: (j['dagitim'] as String?) ?? 'daire_basina',
    tutarKurus: (j['tutar_kurus'] as num?)?.toInt(),
    toplamTutarKurus: (j['toplam_tutar_kurus'] as num?)?.toInt(),
    gun: (j['tahakkuk_gunu'] as num?)?.toInt() ?? 1,
    vadeGun: (j['vade_gun'] as num?)?.toInt() ?? 0,
    aktif: (j['aktif'] as bool?) ?? true,
    ertelenenDonem: j['ertelenen_donem'] as String?,
  );
}

class GiderKurali {
  const GiderKurali({
    required this.id,
    required this.ad,
    required this.tutarKurus,
    required this.periyot,
    required this.sonrakiTarih,
    required this.otomatikOnay,
    required this.aktif,
  });

  final String id;
  final String ad;
  final int tutarKurus;
  final String periyot;
  final DateTime sonrakiTarih;
  final bool otomatikOnay;
  final bool aktif;

  factory GiderKurali.fromJson(Map<String, dynamic> j) => GiderKurali(
    id: j['id'] as String,
    ad: (j['ad'] as String?) ?? '',
    tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
    periyot: (j['periyot'] as String?) ?? 'aylik',
    sonrakiTarih: DateTime.parse(j['sonraki_tarih'] as String),
    otomatikOnay: (j['otomatik_onay'] as bool?) ?? false,
    aktif: (j['aktif'] as bool?) ?? true,
  );
}

class GecikmeKurali {
  const GecikmeKurali({required this.yuzde, required this.uygula});
  final double yuzde;
  final bool uygula;

  factory GecikmeKurali.fromJson(Map<String, dynamic> j) => GecikmeKurali(
    yuzde: (j['gecikme_aylik_yuzde'] as num?)?.toDouble() ?? 0,
    uygula: (j['gecikme_uygula'] as bool?) ?? false,
  );
}

class SonCalisma {
  const SonCalisma({
    required this.kural,
    required this.tur,
    required this.zaman,
    required this.adet,
    required this.tutarKurus,
    this.durum,
  });
  final String kural;
  final String tur;
  final DateTime zaman;
  final int adet;
  final int tutarKurus;
  final String? durum;

  factory SonCalisma.fromJson(Map<String, dynamic> j) => SonCalisma(
    kural: j['kural'] as String,
    tur: j['tur'] as String,
    zaman: DateTime.parse(j['zaman'] as String),
    adet: (j['adet'] as num?)?.toInt() ?? 0,
    tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
    durum: j['durum'] as String?,
  );
}

class KuralOnizleme {
  const KuralOnizleme({
    required this.adet,
    required this.toplamKurus,
    this.atlanan = 0,
    this.ilkTarih,
  });
  final int adet;
  final int toplamKurus;
  final int atlanan;
  final DateTime? ilkTarih;

  factory KuralOnizleme.fromJson(Map<String, dynamic> j) => KuralOnizleme(
    adet: (j['adet'] as num?)?.toInt() ?? 0,
    toplamKurus: (j['toplam_kurus'] as num?)?.toInt() ?? 0,
    atlanan: (j['atlanan'] as num?)?.toInt() ?? 0,
    ilkTarih: j['ilk_tarih'] == null
        ? null
        : DateTime.parse(j['ilk_tarih'] as String),
  );
}

/// Gecikme faizi önizlemesi: kaç borca, toplam ne kadar.
class GecikmeOnizleme {
  const GecikmeOnizleme({required this.adet, required this.toplamKurus});
  final int adet;
  final int toplamKurus;
}

class OtomasyonApi {
  OtomasyonApi(this._dio);
  final Dio _dio;

  Future<T> _sar<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  List<Map<String, dynamic>> _ogeler(Response<Map<String, dynamic>> r) => [
    for (final m in ((r.data?['items'] as List?) ?? const []))
      Map<String, dynamic>.from(m as Map),
  ];

  Future<List<PlanKurali>> planlar() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>('/aidat-planlari');
    return _ogeler(r).map(PlanKurali.fromJson).toList();
  });

  Future<List<GiderKurali>> giderler() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>('/duzenli-giderler');
    return _ogeler(r).map(GiderKurali.fromJson).toList();
  });

  Future<GecikmeKurali> gecikme() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/borclandirma/gecikme-ayari',
    );
    return GecikmeKurali.fromJson(r.data!);
  });

  Future<Map<String, SonCalisma>> sonCalismalar() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>('/otomasyon/son-calismalar');
    return {
      for (final s in _ogeler(r).map(SonCalisma.fromJson)) s.kural: s,
    };
  });

  Future<KuralOnizleme> hatirlatmaOnizleme() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>('/hatirlatma-ayari/onizleme');
    return KuralOnizleme.fromJson(r.data!);
  });

  Future<GecikmeOnizleme> gecikmeOnizleme() => _sar(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/borclandirma/gecikme-faizi/onizleme',
    );
    final ogeler = _ogeler(r);
    return GecikmeOnizleme(
      adet: ogeler
          .where((o) => ((o['fark_kurus'] as num?) ?? 0) > 0)
          .length,
      toplamKurus: (r.data?['toplam_fark_kurus'] as num?)?.toInt() ?? 0,
    );
  });

  /// KAYDETMEZ: "bu kural bugün çalışsaydı".
  Future<KuralOnizleme> planOnizleme(Map<String, dynamic> govde) =>
      _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/aidat-planlari/onizleme',
          data: govde,
        );
        return KuralOnizleme.fromJson(r.data!);
      });

  Future<void> planEkle(Map<String, dynamic> govde) =>
      _sar(() => _dio.post<void>('/aidat-planlari', data: govde));
  Future<void> giderEkle(Map<String, dynamic> govde) =>
      _sar(() => _dio.post<void>('/duzenli-giderler', data: govde));
  Future<void> planAktif(String id, bool aktif) => _sar(
    () => _dio.patch<void>('/aidat-planlari/$id', data: {'aktif': aktif}),
  );
  Future<void> giderAktif(String id, bool aktif) => _sar(
    () => _dio.patch<void>('/duzenli-giderler/$id', data: {'aktif': aktif}),
  );
  Future<void> gecikmeAktif(bool acik) => _sar(
    () => _dio.patch<void>(
      '/borclandirma/gecikme-ayari',
      data: {'gecikme_uygula': acik},
    ),
  );
  Future<void> hatirlatmaAktif(bool acik) => _sar(
    () => _dio.patch<void>('/hatirlatma-ayari', data: {'aktif': acik}),
  );
  Future<void> planErtele(String id, String donem) => _sar(
    () => _dio.post<void>('/aidat-planlari/$id/ertele', data: {'donem': donem}),
  );
  Future<void> planSil(String id) =>
      _sar(() => _dio.delete<void>('/aidat-planlari/$id'));
  Future<void> giderSil(String id) =>
      _sar(() => _dio.delete<void>('/duzenli-giderler/$id'));
}

final otomasyonApiProvider = Provider<OtomasyonApi>(
  (ref) => OtomasyonApi(ref.watch(dioProvider)),
);
final planKurallariProvider = FutureProvider.autoDispose<List<PlanKurali>>(
  (ref) => ref.watch(otomasyonApiProvider).planlar(),
);
final giderKurallariProvider = FutureProvider.autoDispose<List<GiderKurali>>(
  (ref) => ref.watch(otomasyonApiProvider).giderler(),
);
final gecikmeKuraliProvider = FutureProvider.autoDispose<GecikmeKurali>(
  (ref) => ref.watch(otomasyonApiProvider).gecikme(),
);
final sonCalismalarProvider =
    FutureProvider.autoDispose<Map<String, SonCalisma>>(
      (ref) => ref.watch(otomasyonApiProvider).sonCalismalar(),
    );
final hatirlatmaOnizlemeProvider = FutureProvider.autoDispose<KuralOnizleme>(
  (ref) => ref.watch(otomasyonApiProvider).hatirlatmaOnizleme(),
);
final gecikmeOnizlemeProvider = FutureProvider.autoDispose<GecikmeOnizleme>(
  (ref) => ref.watch(otomasyonApiProvider).gecikmeOnizleme(),
);
