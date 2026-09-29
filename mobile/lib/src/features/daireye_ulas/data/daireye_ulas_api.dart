import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P249 §3) Guvenlikten daireye ulasma — daire ozeti, telefon yedegi,
/// sesli mesaj.
///
/// NUMARA HICBIR LISTEDE YOK: daire ozeti yalniz "telefonla aranabilir mi"
/// (evet/hayir) doner. Numara `telefon()` ile TEK sakin icin, sakin izin
/// verdiyse ve DENETIM KAYDIYLA acilir.
class UlasSakin {
  const UlasSakin({required this.userId, required this.ad, required this.telefonlaAranabilir});

  final String userId;
  final String ad;
  final bool telefonlaAranabilir;

  factory UlasSakin.fromJson(Map<String, dynamic> j) => UlasSakin(
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        telefonlaAranabilir: (j['telefonla_aranabilir'] as bool?) ?? false,
      );
}

class DaireUlas {
  const DaireUlas({required this.unitId, required this.daire, required this.sakinler});

  final String unitId;
  final String daire;
  final List<UlasSakin> sakinler;

  factory DaireUlas.fromJson(Map<String, dynamic> j) => DaireUlas(
        unitId: j['unit_id'] as String,
        daire: (j['daire'] as String?) ?? '',
        sakinler: ((j['sakinler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => UlasSakin.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class SesliMesaj {
  const SesliMesaj({
    required this.id,
    required this.daire,
    required this.sureMs,
    required this.createdAt,
    this.gonderenAd,
    this.dinlendiAt,
  });

  final String id;
  final String daire;
  final int sureMs;
  final DateTime createdAt;
  final String? gonderenAd;
  final DateTime? dinlendiAt;

  factory SesliMesaj.fromJson(Map<String, dynamic> j) => SesliMesaj(
        id: j['id'] as String,
        daire: (j['daire'] as String?) ?? '',
        sureMs: (j['sure_ms'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        gonderenAd: j['gonderen_ad'] as String?,
        dinlendiAt: j['dinlendi_at'] == null
            ? null
            : DateTime.tryParse(j['dinlendi_at'] as String),
      );
}

class DaireyeUlasApi {
  DaireyeUlasApi(this._dio, [Dio? yuklemeDio]) : _yuklemeDio = yuklemeDio ?? Dio();

  final Dio _dio;

  /// Imzali adrese PUT — kimlik basligi TASIMAZ (imza zaten adreste).
  final Dio _yuklemeDio;

  /// (P249 §3b) Kayit bicimi: AAC (m4a). Sunucu da yalniz bunu kabul eder.
  static const icerikTuru = 'audio/mp4';

  Future<T> _cagir<T>(Future<T> Function() is_) async {
    try {
      return await is_();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DaireUlas> daire(String unitId) => _cagir(() async {
        final r = await _dio.get<Map<String, dynamic>>('/units/$unitId/ulas');
        return DaireUlas.fromJson(r.data ?? const {});
      });

  /// TEK sakinin numarasi — yalniz izin aciksa (degilse 403).
  Future<String> telefon(String unitId, String userId) => _cagir(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/units/$unitId/ulas/telefon',
          data: {'user_id': userId},
        );
        return (r.data?['telefon'] as String?) ?? '';
      });

  /// Sesli mesaji yukle ve gonder: imzali adres -> PUT -> gonder.
  Future<void> sesGonder(String unitId, Uint8List ses, int sureMs) => _cagir(() async {
        final y = await _dio.post<Map<String, dynamic>>(
          '/units/$unitId/sesli-mesaj/yukleme',
          data: {'icerik_turu': icerikTuru, 'boyut': ses.length},
        );
        final anahtar = y.data?['anahtar'] as String? ?? '';
        final url = y.data?['url'] as String? ?? '';
        await _yuklemeDio.put<void>(
          url,
          data: Stream.fromIterable([ses]),
          options: Options(headers: {
            Headers.contentTypeHeader: icerikTuru,
            Headers.contentLengthHeader: ses.length,
          }),
        );
        await _dio.post<Map<String, dynamic>>(
          '/units/$unitId/sesli-mesaj',
          data: {
            'anahtar': anahtar,
            'sure_ms': sureMs,
            'boyut': ses.length,
            'icerik_turu': icerikTuru,
          },
        );
      });

  Future<List<SesliMesaj>> mesajlar() => _cagir(() async {
        final r = await _dio.get<List<dynamic>>('/sesli-mesaj');
        return (r.data ?? const [])
            .whereType<Map>()
            .map((m) => SesliMesaj.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      });

  /// Kisa omurlu dinleme adresi.
  Future<String> dinle(String id) => _cagir(() async {
        final r = await _dio.get<Map<String, dynamic>>('/sesli-mesaj/$id/dinle');
        return (r.data?['url'] as String?) ?? '';
      });

  Future<void> sil(String id) => _cagir(() async {
        await _dio.delete<void>('/sesli-mesaj/$id');
      });
}

final daireyeUlasApiProvider =
    Provider<DaireyeUlasApi>((ref) => DaireyeUlasApi(ref.watch(dioProvider)));

final sesliMesajlarProvider = FutureProvider.autoDispose<List<SesliMesaj>>(
  (ref) => ref.watch(daireyeUlasApiProvider).mesajlar(),
);
