import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/budget_models.dart';

/// Butce endpoint'lerinin ince HTTP istemcisi:
///   * GET/POST `/budget/categories`, PATCH `/budget/categories/{id}`
///   * GET/POST `/budget/entries`
///   * GET `/budget/summary`
/// Tutarlar HER YONDE integer kurus tasinir.
class BudgetApi {
  BudgetApi(this._dio);

  final Dio _dio;

  Future<List<BudgetCategory>> fetchCategories({BudgetTip? tip}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/budget/categories',
        queryParameters: {
          'limit': 200,
          if (tip != null) 'tip': tip.wire,
        },
      );
      return ((res.data!['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BudgetCategory.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetCategory> createCategory({
    required String ad,
    required BudgetTip tip,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/budget/categories',
        data: {'ad': ad, 'tip': tip.wire},
      );
      return BudgetCategory.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetCategory> updateCategory(
    String id, {
    String? ad,
    bool? aktif,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/budget/categories/$id',
        data: {'ad': ?ad, 'aktif': ?aktif},
      );
      return BudgetCategory.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<BudgetEntry>> fetchEntries({
    BudgetTip? tip,
    String? kategoriId,
    String? donem,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/budget/entries',
        queryParameters: {
          'limit': 200,
          if (tip != null) 'tip': tip.wire,
          'kategori_id': ?kategoriId,
          'donem': ?donem,
        },
      );
      return ((res.data!['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BudgetEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetEntry> createEntry({
    required String kategoriId,
    required int tutarKurus,
    required DateTime tarih,
    String? aciklama,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/budget/entries',
        data: {
          'kategori_id': kategoriId,
          'tutar_kurus': tutarKurus, // INTEGER KURUS
          'tarih':
              '${tarih.year.toString().padLeft(4, '0')}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}',
          if (aciklama != null && aciklama.isNotEmpty) 'aciklama': aciklama,
        },
      );
      return BudgetEntry.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetSummary> fetchSummary({String? donem}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/budget/summary',
        queryParameters: {'donem': ?donem},
      );
      return BudgetSummary.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /reports/financial-summary` — cepten finansal ozet (Wave 2B).
  /// Sunucu rol-duyarlidir: sakin/saha yanitinda `tahsilat` null gelir.
  Future<FinancialSummary> fetchFinancialSummary({String? donem}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/reports/financial-summary',
        queryParameters: {'donem': ?donem},
      );
      return FinancialSummary.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final budgetApiProvider = Provider<BudgetApi>((ref) {
  return BudgetApi(ref.watch(dioProvider));
});

/// Guncel donem finansal ozeti (donem=null → sunucu varsayilani). Yonetici
/// ana ekran "Hızlı Özet" bolumu kullanir; ekran acilisinda bir kez cekilir
/// (autoDispose — ekrandan cikinca birakilir).
final financialSummaryProvider =
    FutureProvider.autoDispose<FinancialSummary>((ref) {
  return ref.watch(budgetApiProvider).fetchFinancialSummary();
});
