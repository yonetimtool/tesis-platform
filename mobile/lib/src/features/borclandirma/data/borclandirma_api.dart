/// (P253 Asama 2) BORCLANDIRMA — yonetici mobil istemcisi.
///
/// Web `finans/borclandirmalar` ve daire ayrintisiyla AYNI uclar ve AYNI
/// govdeler; mobil icin ayri uc ya da gevsetilmis dogrulama YOK (§C-3).
/// Yetki sunucuda (admin + yonetici).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/borclandirma_models.dart';

class BorclandirmaApi {
  BorclandirmaApi(this._dio);

  final Dio _dio;

  static String _gun(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<T> _sar<T>(Future<T> Function() is_) async {
    try {
      return await is_();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Borclandirma listesi (web ile ayni sayfalama + tur suzgeci).
  Future<({List<Tahakkuk> items, int toplam})> tahakkuklar({
    required int limit,
    required int offset,
    String? tanimId,
  }) =>
      _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/dues/assessments',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'gelir_gider_tanim_id': ?tanimId,
          },
        );
        final d = r.data ?? const {};
        return (
          items: [
            for (final m in (d['items'] as List?) ?? const [])
              if (m is Map) Tahakkuk.fromJson(Map<String, dynamic>.from(m)),
          ],
          toplam: ((d['meta'] as Map?)?['total'] as num?)?.toInt() ?? 0,
        );
      });

  /// Tekil borclandirma (web `TekilModal` ile ayni govde).
  Future<TahakkukSonucu> tekil({
    required String unitId,
    required String donem,
    required int tutarKurus,
    String? tanimId,
    DateTime? tarih,
    DateTime? sonOdeme,
    String? aciklama,
    bool gecikmeUygula = true,
  }) =>
      _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/dues/assessments',
          data: {
            'unit_id': unitId,
            'donem': donem,
            'tutar_kurus': tutarKurus,
            'son_odeme_tarihi': sonOdeme == null ? null : _gun(sonOdeme),
            'aciklama': aciklama,
            'gelir_gider_tanim_id': tanimId,
            'tarih': tarih == null ? null : _gun(tarih),
            'gecikme_uygula': gecikmeUygula,
          },
        );
        return TahakkukSonucu.fromJson(r.data ?? const {});
      });

  /// Ters kayit — §C-2: sebep ZORUNLU (sunucu da 422 `sebep_zorunlu`).
  Future<void> tersKayit(String assessmentId, String sebep) => _sar(() async {
        await _dio.post<Map<String, dynamic>>(
          '/dues/assessments/$assessmentId/ters-kayit',
          data: {'aciklama': sebep},
        );
      });

  /// Daire odemesi (web daire ayrintisi "tahsilat" ile ayni govde).
  Future<void> odeme({
    required String unitId,
    required int tutarKurus,
    required String yontem,
    required String idempotencyKey,
    String? assessmentId,
    String? makbuzNo,
    String? donem,
  }) =>
      _sar(() async {
        await _dio.post<Map<String, dynamic>>(
          '/dues/payments',
          data: {
            'unit_id': unitId,
            'tutar_kurus': tutarKurus,
            'yontem': yontem,
            'makbuz_no': makbuzNo,
            'assessment_id': assessmentId,
            // Tahakkuk seciliyse sunucu donemi ondan turetir.
            'donem': assessmentId == null ? donem : null,
          },
          options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
      });

  /// Daire borc durumu.
  Future<DaireBorcu> daireBorcu(String unitId) => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>('/units/$unitId/dues');
        return DaireBorcu.fromJson(r.data ?? const {});
      });

  Future<TopluOnizleme> topluOnizleme(TopluBorcGovdesi g) => _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/borclandirma/toplu/onizleme',
          data: g.toJson(),
        );
        return TopluOnizleme.fromJson(r.data ?? const {});
      });

  Future<TahakkukSonucu> topluIsle(TopluBorcGovdesi g) => _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/borclandirma/toplu',
          data: g.toJson(),
        );
        return TahakkukSonucu.fromJson(r.data ?? const {});
      });

  /// (P253 §C-4) Toplu tahakkuk partisini TERS KAYITLA geri al — sebep
  /// zorunlu. `atlananlar`: odeme almis (`odenmis`) ya da zaten duzeltilmis.
  Future<TahakkukSonucu> partiGeriAl(String partiId, String sebep) => _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/borclandirma/parti/$partiId/geri-al',
          data: {'aciklama': sebep},
        );
        final j = r.data ?? const {};
        return TahakkukSonucu.fromJson({...j, 'olusan': j['geri_alinan']});
      });

  Future<FaizOnizleme> faizOnizleme() => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/borclandirma/gecikme-faizi/onizleme',
        );
        return FaizOnizleme.fromJson(r.data ?? const {});
      });

  /// Birikmis faizi borc kalemi olarak yaz — yazilan kalem sayisi.
  Future<int> faizIsle() => _sar(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/borclandirma/gecikme-faizi/isle',
        );
        return (r.data?['yazilan'] as num?)?.toInt() ?? 0;
      });

  /// Daireler — secici ve kart etiketleri icin (sunucu tavani 1000).
  Future<List<DaireKisa>> daireler() => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/units',
          queryParameters: {'limit': 1000, 'aktif': true},
        );
        return [
          for (final m in (r.data?['items'] as List?) ?? const [])
            if (m is Map) DaireKisa.fromJson(Map<String, dynamic>.from(m)),
        ];
      });

  /// Borclandirma turleri — GELIR tanimlari HARIC (bir gelir borclandirilmaz;
  /// sunucu da 422 verir).
  Future<List<BorcTuru>> turler() => _sar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/gelir-gider-tanimlari',
          queryParameters: {'limit': 200},
        );
        return [
          for (final m in (r.data?['items'] as List?) ?? const [])
            if (m is Map && m['tip'] != 'gelir')
              BorcTuru(id: m['id'] as String, ad: (m['ad'] as String?) ?? ''),
        ];
      });
}

final borclandirmaApiProvider = Provider<BorclandirmaApi>(
  (ref) => BorclandirmaApi(ref.watch(dioProvider)),
);

/// Daireler ve turler — ekranlar arasinda paylasilan, bir kez yuklenen.
final borcDairelerProvider = FutureProvider.autoDispose<List<DaireKisa>>(
  (ref) => ref.watch(borclandirmaApiProvider).daireler(),
);
final borcTurleriProvider = FutureProvider.autoDispose<List<BorcTuru>>(
  (ref) => ref.watch(borclandirmaApiProvider).turler(),
);
