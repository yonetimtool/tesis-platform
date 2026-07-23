import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/transparency_models.dart';

/// Şeffaflık Panosu HTTP istemcisi. Sakin: yayınlanmış aylar; yönetici: hepsi +
/// yayınla/geri-al. Backend RBAC + yayın kapısını zorlar.
class TransparencyApi {
  TransparencyApi(this._dio);

  final Dio _dio;

  Future<List<TransparencyAyOzet>> fetchMonths() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/transparency');
      final items = (res.data?['items'] as List<dynamic>?) ?? const [];
      return items
          .map((e) => TransparencyAyOzet.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TransparencyBoard> fetchBoard(String ay) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/transparency/$ay');
      return TransparencyBoard.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TransparencyBoard> setPublish(String ay, bool yayin) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/transparency/$ay/publish',
        data: {'yayin': yayin},
      );
      return TransparencyBoard.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final transparencyApiProvider =
    Provider<TransparencyApi>((ref) => TransparencyApi(ref.watch(dioProvider)));
