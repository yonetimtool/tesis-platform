import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (E2E 2026-09, MOBIL-10) DAVETLER — yoneticinin "gitmeyen daveti" gorup
/// yeniden gondermesi. Web `/davetler` sayfasinin mobil ikizi; P204 parite
/// analizi "Evet — sahada gerçek ihtiyaç" demisti (yonetici sakini kapida
/// ekler, davet gitmediyse orada yeniden gonderir).
///
///   * `GET  /davet`               -> tesisin davetleri + tesis kodu
///   * `POST /davet/{user_id}/yeniden` -> jetonu tazele + yeniden gonder
///
/// RBAC sunucuda: admin + yonetici (`davet._YONETIM`).
class DavetSatiri {
  const DavetSatiri({
    required this.userId,
    required this.ad,
    required this.rol,
    required this.telefon,
    this.daireNo,
    this.sonKanal,
    this.sonDurum,
    this.sonHata,
    this.sonGonderimAt,
    this.usedAt,
  });

  final String userId;
  final String ad;
  final String rol;
  final String telefon;
  final String? daireNo;
  final String? sonKanal;
  final String? sonDurum;
  final String? sonHata;
  final DateTime? sonGonderimAt;
  final DateTime? usedAt;

  factory DavetSatiri.fromJson(Map<String, dynamic> j) => DavetSatiri(
    userId: j['user_id'] as String? ?? '',
    ad: j['ad'] as String? ?? '',
    rol: j['rol'] as String? ?? '',
    telefon: j['telefon'] as String? ?? '',
    daireNo: j['daire_no'] as String?,
    sonKanal: j['son_kanal'] as String?,
    sonDurum: j['son_durum'] as String?,
    sonHata: j['son_hata'] as String?,
    sonGonderimAt: DateTime.tryParse(j['son_gonderim_at'] as String? ?? ''),
    usedAt: DateTime.tryParse(j['used_at'] as String? ?? ''),
  );
}

class DavetListesi {
  const DavetListesi({required this.items, this.tesisKodu});

  final List<DavetSatiri> items;

  /// Saglayici yokken ELLE iletim yedegi (web ile ayni).
  final String? tesisKodu;
}

/// Davetin gorunen durumu — web `durumBilgisi` ile AYNI sira ve AYNI
/// ayrim (E2E 2026-09: saglayici geri bildirimi her durumu ayri etiketler).
enum DavetDurumu {
  kaydoldu,
  geriDondu,
  gitmedi,
  ayarYok,
  acildi,
  iletildi,
  gonderildi,
  bekliyor,
}

/// Resend geri donusu (bounce) hata kodu — `eposta_webhook.OLAY_ESLEME`.
const _hataGeriDondu = 'bounce';

DavetDurumu davetDurumu(DavetSatiri d) {
  if (d.usedAt != null) return DavetDurumu.kaydoldu;
  if (d.sonDurum == 'basarisiz' && d.sonHata == _hataGeriDondu) {
    return DavetDurumu.geriDondu;
  }
  return switch (d.sonDurum) {
    'basarisiz' => DavetDurumu.gitmedi,
    'yapilandirilmadi' => DavetDurumu.ayarYok,
    'okundu' => DavetDurumu.acildi,
    'iletildi' => DavetDurumu.iletildi,
    'gonderildi' => DavetDurumu.gonderildi,
    _ => DavetDurumu.bekliyor,
  };
}

class DavetYonetimApi {
  DavetYonetimApi(this._dio);

  final Dio _dio;

  Future<DavetListesi> liste() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/davet');
      final ham = (res.data?['items'] as List?) ?? const [];
      return DavetListesi(
        tesisKodu: res.data?['tesis_kodu'] as String?,
        items: ham
            .whereType<Map>()
            .map((m) => DavetSatiri.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> yenidenGonder(String userId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/davet/$userId/yeniden');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final davetYonetimApiProvider = Provider<DavetYonetimApi>(
  (ref) => DavetYonetimApi(ref.watch(dioProvider)),
);

final davetListesiProvider = FutureProvider.autoDispose<DavetListesi>(
  (ref) => ref.watch(davetYonetimApiProvider).liste(),
);
