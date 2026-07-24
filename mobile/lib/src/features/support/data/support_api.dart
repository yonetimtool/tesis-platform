import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/support_models.dart';

/// POST/GET /support — yonetici destek kanali (WP1). Admin yaniti panelden.
class SupportApi {
  SupportApi(this._dio);
  final Dio _dio;

  Future<List<SupportTicket>> fetchMine({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/support',
      queryParameters: {'limit': limit},
    );
    return [
      for (final item in (res.data?['items'] as List?) ?? const [])
        if (item is Map)
          SupportTicket.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<SupportTicket> create({
    required String konu,
    required String aciklama,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/support',
      data: {'konu': konu, 'aciklama': aciklama},
    );
    return SupportTicket.fromJson(res.data ?? const {});
  }
}

final supportApiProvider = Provider<SupportApi>((ref) {
  return SupportApi(ref.watch(dioProvider));
});

/// Yoneticinin kendi biletleri (en-yeni-ustte sunucu sirasi).
final myTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  return ref.watch(supportApiProvider).fetchMine();
});
