import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/panik_models.dart';

/// (P249 §2) Tatbikat — `/tatbikat`.
class Tatbikat {
  const Tatbikat({
    required this.id,
    required this.kategori,
    required this.kapsam,
    required this.durum,
    required this.baslik,
    this.blok,
    this.planlananAt,
    this.basladiAt,
    this.bittiAt,
    this.bitisNedeni,
    this.duyuruGonderildi = false,
    this.alarmId,
    this.olusturanAd,
  });

  final String id;
  final String kategori;
  final String kapsam;

  /// `planli` | `aktif` | `bitti` | `iptal`
  final String durum;

  /// Istegin dilinde ad ("Deprem tatbikati") — sunucudan.
  final String baslik;
  final String? blok;
  final DateTime? planlananAt;
  final DateTime? basladiAt;
  final DateTime? bittiAt;
  final String? bitisNedeni;
  final bool duyuruGonderildi;
  final String? alarmId;
  final String? olusturanAd;

  factory Tatbikat.fromJson(Map<String, dynamic> j) {
    DateTime? t(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return Tatbikat(
      id: j['id'] as String,
      kategori: (j['kategori'] as String?) ?? '',
      kapsam: (j['kapsam'] as String?) ?? 'site',
      durum: (j['durum'] as String?) ?? '',
      baslik: (j['baslik'] as String?) ?? '',
      blok: j['blok'] as String?,
      planlananAt: t('planlanan_at'),
      basladiAt: t('basladi_at'),
      bittiAt: t('bitti_at'),
      bitisNedeni: j['bitis_nedeni'] as String?,
      duyuruGonderildi: j['duyuru_gonderildi_at'] != null,
      alarmId: j['alarm_id'] as String?,
      olusturanAd: j['olusturan_ad'] as String?,
    );
  }
}

class TatbikatRaporu {
  const TatbikatRaporu({
    required this.tatbikat,
    this.durum,
    this.pushDenenen = 0,
    this.pushGonderildi = 0,
  });

  final Tatbikat tatbikat;
  final PanikDurum? durum;
  final int pushDenenen;
  final int pushGonderildi;

  factory TatbikatRaporu.fromJson(Map<String, dynamic> j) => TatbikatRaporu(
        tatbikat: Tatbikat.fromJson(Map<String, dynamic>.from(j['tatbikat'] as Map)),
        durum: j['durum'] == null
            ? null
            : PanikDurum.fromJson(Map<String, dynamic>.from(j['durum'] as Map)),
        pushDenenen: (j['push_denenen'] as num?)?.toInt() ?? 0,
        pushGonderildi: (j['push_gonderildi'] as num?)?.toInt() ?? 0,
      );
}

class TatbikatApi {
  TatbikatApi(this._dio);

  final Dio _dio;

  Future<List<Tatbikat>> liste() async {
    try {
      final res = await _dio.get<List<dynamic>>('/tatbikat');
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => Tatbikat.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `planlananAt` null -> HEMEN baslar.
  Future<Tatbikat> planla({
    required String kategori,
    required String kapsam,
    String? blok,
    DateTime? planlananAt,
    bool duyuru = false,
    String? aciklama,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/tatbikat', data: {
        'kategori': kategori,
        'kapsam': kapsam,
        'blok': ?blok,
        // SAAT DILIMIYLE: sunucu dilimsiz zamani reddeder (14:00 hangi
        // saatte 14:00?).
        if (planlananAt != null) 'planlanan_at': planlananAt.toUtc().toIso8601String(),
        'duyuru': duyuru,
        if (aciklama != null && aciklama.isNotEmpty) 'aciklama': aciklama,
      });
      return Tatbikat.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Tatbikat> eylem(String id, String eylem) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/tatbikat/$id/$eylem');
      return Tatbikat.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TatbikatRaporu> rapor(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/tatbikat/$id');
      return TatbikatRaporu.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final tatbikatApiProvider =
    Provider<TatbikatApi>((ref) => TatbikatApi(ref.watch(dioProvider)));

final tatbikatListeProvider = FutureProvider.autoDispose<List<Tatbikat>>(
  (ref) => ref.watch(tatbikatApiProvider).liste(),
);

final tatbikatRaporProvider =
    FutureProvider.autoDispose.family<TatbikatRaporu, String>(
  (ref, id) => ref.watch(tatbikatApiProvider).rapor(id),
);
