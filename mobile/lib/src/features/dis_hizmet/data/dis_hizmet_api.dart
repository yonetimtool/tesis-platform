import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Dis hizmet kaydi (guvenilir esnaf/hizmet kisisi).
class DisHizmet {
  const DisHizmet({
    required this.id,
    required this.tur,
    required this.ad,
    required this.soyad,
    required this.telefon,
    this.aciklama,
  });

  final String id;
  final String tur;
  final String ad;
  final String soyad;
  final String telefon;
  final String? aciklama;

  String get adSoyad => '$ad $soyad';

  factory DisHizmet.fromJson(Map<String, dynamic> json) => DisHizmet(
        id: json['id'] as String,
        tur: json['tur'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        soyad: json['soyad'] as String? ?? '',
        telefon: json['telefon'] as String? ?? '',
        aciklama: json['aciklama'] as String?,
      );
}

/// `GET /external-services` yaniti: bolum notu + kisiler.
class DisHizmetList {
  const DisHizmetList({this.note, required this.items});

  final String? note;
  final List<DisHizmet> items;

  factory DisHizmetList.fromJson(Map<String, dynamic> json) => DisHizmetList(
        note: json['note'] as String?,
        items: ((json['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DisHizmet.fromJson)
            .toList(),
      );
}

/// `/external-services` ince istemcisi. Okuma tum roller; yazma admin+yonetici.
class DisHizmetApi {
  DisHizmetApi(this._dio);

  final Dio _dio;

  Future<DisHizmetList> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/external-services');
      return DisHizmetList.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> create({
    required String tur,
    required String ad,
    required String soyad,
    required String telefon,
    String? aciklama,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>('/external-services', data: {
        'tur': tur,
        'ad': ad,
        'soyad': soyad,
        'telefon': telefon,
        'aciklama': ?aciklama,
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> update(
    String id, {
    required String tur,
    required String ad,
    required String soyad,
    required String telefon,
    String? aciklama,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/external-services/$id', data: {
        'tur': tur,
        'ad': ad,
        'soyad': soyad,
        'telefon': telefon,
        'aciklama': aciklama, // null -> temizle
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/external-services/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> setNote(String? note) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/external-services/note',
        data: {'note': note},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final disHizmetApiProvider =
    Provider<DisHizmetApi>((ref) => DisHizmetApi(ref.watch(dioProvider)));

final disHizmetlerProvider = FutureProvider.autoDispose<DisHizmetList>(
  (ref) => ref.watch(disHizmetApiProvider).fetch(),
);
