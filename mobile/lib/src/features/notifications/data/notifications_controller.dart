import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/notification_models.dart';

/// GET /notifications + PATCH /notifications/{id} istemcisi.
/// RBAC: admin + yonetici + security (sakin/tesis gorevlisi ERISEMEZ —
/// inbox o rollerin ekranlarina baglanmaz).
class NotificationsApi {
  NotificationsApi(this._dio);
  final Dio _dio;

  Future<NotificationPage> fetch({
    bool? okundu,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'okundu': ?okundu,
      },
    );
    return NotificationPage.fromJson(res.data ?? const {});
  }

  Future<void> markRead(String id) async {
    await _dio.patch<Map<String, dynamic>>(
      '/notifications/$id',
      data: {'okundu': true},
    );
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(dioProvider));
});

/// Okunmamis bildirim sayisi — HomeShell zil/sekme rozeti. okundu=false +
/// limit=1 sorgusunun meta.total'i; hata → izleyen ekran 0 varsayar (ana
/// ekran rozete rehin degil).
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final page = await ref
      .watch(notificationsApiProvider)
      .fetch(okundu: false, limit: 1);
  return page.total;
});

/// Bildirim listesi + okundu isaretleme. Isaretleme IYIMSER: satir hemen
/// okunmus gorunur, rozet sayaci tazelenir.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final page = await ref.watch(notificationsApiProvider).fetch();
    return page.items;
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationsApiProvider).markRead(id);
    state = AsyncData([
      for (final n in state.value ?? <AppNotification>[])
        n.id == id ? n.copyWith(okundu: true) : n,
    ]);
    ref.invalidate(unreadNotificationCountProvider);
  }
}

final notificationsProvider = AsyncNotifierProvider.autoDispose<
    NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);
