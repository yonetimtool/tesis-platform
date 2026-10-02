/// (P250 §4) Kurulum eğitim videoları — web ile AYNI uçlar ve AYNI veri.
///
///   * `GET  /egitim-videolari`               — adımlar + video + izlendi,
///   * `POST /egitim-videolari/{adim}/izlendi` — video BİTİNCE.
///
/// İzlendi bilgisi HESAPTA: web'de izlenen video mobilde de işaretli.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class EgitimVideo {
  const EgitimVideo({
    required this.youtubeId,
    required this.baslik,
    this.aciklama,
  });

  final String youtubeId;
  final String baslik;
  final String? aciklama;
}

class EgitimAdim {
  const EgitimAdim({required this.adimKodu, this.video, this.izlendi = false});

  final String adimKodu;

  /// Aktif video yoksa null -> "yakında" (kırık oynatıcı YOK).
  final EgitimVideo? video;
  final bool izlendi;

  factory EgitimAdim.fromJson(Map<String, dynamic> j) {
    final v = j['video'] as Map<String, dynamic>?;
    return EgitimAdim(
      adimKodu: j['adim_kodu'] as String,
      izlendi: (j['izlendi'] as bool?) ?? false,
      video: v == null
          ? null
          : EgitimVideo(
              youtubeId: v['youtube_id'] as String,
              baslik: v['baslik'] as String,
              aciklama: v['aciklama'] as String?,
            ),
    );
  }
}

class EgitimListe {
  const EgitimListe({
    required this.adimlar,
    required this.toplam,
    required this.izlenen,
    required this.kurulumTamam,
  });

  final List<EgitimAdim> adimlar;
  final int toplam;
  final int izlenen;
  final bool kurulumTamam;

  factory EgitimListe.fromJson(Map<String, dynamic> j) => EgitimListe(
    adimlar: [
      for (final a in (j['adimlar'] as List))
        EgitimAdim.fromJson(a as Map<String, dynamic>),
    ],
    toplam: (j['toplam'] as num?)?.toInt() ?? 0,
    izlenen: (j['izlenen'] as num?)?.toInt() ?? 0,
    kurulumTamam: (j['kurulum_tamam'] as bool?) ?? false,
  );
}

class EgitimApi {
  EgitimApi(this._dio);

  final Dio _dio;

  Future<EgitimListe> liste() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/egitim-videolari');
      return EgitimListe.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> izlendi(String adimKodu) async {
    try {
      await _dio.post<void>('/egitim-videolari/$adimKodu/izlendi');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final egitimApiProvider = Provider<EgitimApi>(
  (ref) => EgitimApi(ref.watch(dioProvider)),
);

/// Liste — izlendi yazilinca `ref.invalidate(egitimListesiProvider)`.
final egitimListesiProvider = FutureProvider<EgitimListe>(
  (ref) => ref.watch(egitimApiProvider).liste(),
);
