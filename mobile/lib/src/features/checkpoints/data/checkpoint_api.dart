import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// NFC kontrol noktasi (checkpoint) — yonetici uygulamada tanimlar (Parca D).
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.ad,
    required this.nfcTagUid,
    required this.aktif,
    this.gpsLat,
    this.gpsLng,
    this.sdmAktif = false,
  });

  final String id;
  final String ad;
  final String nfcTagUid;
  final bool aktif;
  final double? gpsLat;
  final double? gpsLng;
  final bool sdmAktif;

  factory Checkpoint.fromJson(Map<String, dynamic> json) => Checkpoint(
        id: json['id'] as String,
        ad: json['ad'] as String? ?? '',
        nfcTagUid: json['nfc_tag_uid'] as String? ?? '',
        aktif: (json['aktif'] as bool?) ?? true,
        gpsLat: (json['gps_lat'] as num?)?.toDouble(),
        gpsLng: (json['gps_lng'] as num?)?.toDouble(),
        sdmAktif: (json['sdm_aktif'] as bool?) ?? false,
      );
}

/// `GET/POST/PATCH/DELETE /checkpoints` ince istemcisi (yonetici/admin yazar;
/// SDM-key provizyonu admin-only kaldigi icin BURADA yok).
class CheckpointApi {
  CheckpointApi(this._dio);

  final Dio _dio;

  Future<List<Checkpoint>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/checkpoints',
        queryParameters: {'limit': 200},
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(Checkpoint.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Checkpoint> create({
    required String ad,
    required String nfcTagUid,
    double? gpsLat,
    double? gpsLng,
    bool aktif = true,
  }) async {
    return _write('POST', '/checkpoints', {
      'ad': ad,
      'nfc_tag_uid': nfcTagUid,
      'gps_lat': ?gpsLat,
      'gps_lng': ?gpsLng,
      'aktif': aktif,
    });
  }

  Future<Checkpoint> update(
    String id, {
    String? ad,
    String? nfcTagUid,
    double? gpsLat,
    double? gpsLng,
    bool? aktif,
  }) async {
    return _write('PATCH', '/checkpoints/$id', {
      'ad': ?ad,
      'nfc_tag_uid': ?nfcTagUid,
      'gps_lat': ?gpsLat,
      'gps_lng': ?gpsLng,
      'aktif': ?aktif,
    });
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/checkpoints/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Checkpoint> _write(
      String method, String path, Map<String, dynamic> data) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(method: method),
      );
      return Checkpoint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final checkpointApiProvider =
    Provider<CheckpointApi>((ref) => CheckpointApi(ref.watch(dioProvider)));

final checkpointsProvider = FutureProvider.autoDispose<List<Checkpoint>>(
  (ref) => ref.watch(checkpointApiProvider).list(),
);
