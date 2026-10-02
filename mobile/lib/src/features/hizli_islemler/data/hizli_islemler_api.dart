/// (P250 §6) Hızlı İşlemler — web ile AYNI uç ve AYNI kimlikler.
///
/// Seçim HESAPTA (`pano_tercihi.hizli_islemler`, P182); seçenekler ROLE göre
/// SUNUCUDAN gelir. Bu dosya yalnız "kimlik nereye gider, nasıl görünür"
/// eşlemesini tutar (web eşi: `admin-web/lib/hizli-islemler.ts`).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../routing/app_router.dart';

class HizliIslemTanimi {
  const HizliIslemTanimi(this.etiket, this.ikon, this.rota);
  final String Function(AppLocalizations) etiket;
  final IconData ikon;
  final String rota;
}

/// Kimlik -> mobil karşılığı. Sunucunun bilmediği kimlik ÇİZİLMEZ.
final Map<String, HizliIslemTanimi> hizliIslemKatalogu = {
  'aidat': HizliIslemTanimi(
    (l) => l.panoHizliAidat,
    Icons.payments_outlined,
    AppRoutes.tahsilat,
  ),
  'talep': HizliIslemTanimi(
    (l) => l.panoHizliTalep,
    Icons.chat_bubble_outline,
    AppRoutes.complaints,
  ),
  'duyuru': HizliIslemTanimi(
    (l) => l.panoHizliDuyuru,
    Icons.campaign_outlined,
    AppRoutes.announcements,
  ),
  'personel': HizliIslemTanimi(
    (l) => l.panoHizliPersonel,
    Icons.badge_outlined,
    AppRoutes.personel,
  ),
  'sakin': HizliIslemTanimi(
    (l) => l.panoHizliSakin,
    Icons.home_outlined,
    AppRoutes.sakinler,
  ),
  'gorev': HizliIslemTanimi(
    (l) => l.panoHizliGorev,
    Icons.fact_check_outlined,
    '${AppRoutes.tasks}?gorunum=yonetim',
  ),
  'ziyaretci': HizliIslemTanimi(
    (l) => l.panoHizliZiyaretci,
    Icons.login_outlined,
    AppRoutes.visitors,
  ),
  'borclular': HizliIslemTanimi(
    (l) => l.panoHizliBorclular,
    Icons.schedule_outlined,
    AppRoutes.borclular,
  ),
  'gider': HizliIslemTanimi(
    (l) => l.panoHizliGider,
    Icons.trending_down_outlined,
    AppRoutes.gider,
  ),
  'rezervasyon': HizliIslemTanimi(
    (l) => l.panoHizliRezervasyon,
    Icons.event_available_outlined,
    AppRoutes.rezervasyon,
  ),
  'vardiya': HizliIslemTanimi(
    (l) => l.panoHizliVardiya,
    Icons.access_time,
    AppRoutes.vardiyaPlani,
  ),
  'anket': HizliIslemTanimi(
    (l) => l.panoHizliAnket,
    Icons.bar_chart_outlined,
    AppRoutes.anketler,
  ),
  'rapor': HizliIslemTanimi(
    (l) => l.panoHizliRapor,
    Icons.description_outlined,
    AppRoutes.reports,
  ),
  'kurulum': HizliIslemTanimi(
    (l) => l.panoHizliKurulum,
    Icons.settings_suggest_outlined,
    AppRoutes.kurulum,
  ),
};

const int hizliUstSinir = 8;

class HizliIslemler {
  const HizliIslemler({
    required this.secenekler,
    required this.secili,
    required this.varsayilan,
    required this.ozel,
  });

  final List<String> secenekler;
  final List<String> secili;
  final List<String> varsayilan;
  final bool ozel;

  factory HizliIslemler.fromJson(Map<String, dynamic> j) {
    List<String> l(String k) => [
      for (final x in (j[k] as List? ?? const [])) x as String,
    ];
    return HizliIslemler(
      secenekler: l('secenekler'),
      secili: l('secili'),
      varsayilan: l('varsayilan'),
      ozel: (j['ozel'] as bool?) ?? false,
    );
  }
}

class HizliIslemlerApi {
  HizliIslemlerApi(this._dio);
  final Dio _dio;

  Future<HizliIslemler> getir() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/me/hizli-islemler');
      return HizliIslemler.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `secili: null` = varsayılana dön.
  Future<HizliIslemler> yaz(List<String>? secili) async {
    try {
      final r = await _dio.put<Map<String, dynamic>>(
        '/me/hizli-islemler',
        data: {'secili': secili},
      );
      return HizliIslemler.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final hizliIslemlerApiProvider = Provider<HizliIslemlerApi>(
  (ref) => HizliIslemlerApi(ref.watch(dioProvider)),
);

final hizliIslemlerProvider = FutureProvider<HizliIslemler>(
  (ref) => ref.watch(hizliIslemlerApiProvider).getir(),
);
