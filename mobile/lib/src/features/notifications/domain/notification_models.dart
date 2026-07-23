/// Bildirim modelleri — GET /notifications + PATCH /notifications/{id}
/// (/contracts/openapi.yaml). RBAC: admin + yonetici + security; sakin ve
/// tesis gorevlisi bu uca ERISEMEZ (inbox onlara baglanmaz).
library;

/// Tek bildirim kaydi (NotificationOut). Savunmaci parse: eksik alan
/// patlatmaz; `okundu` varsayilani TRUE — parse hatasi rozet yakmasin.
class AppNotification {
  const AppNotification({
    required this.id,
    this.tip = '',
    this.mesaj = '',
    this.okundu = true,
    this.createdAt,
    this.patrolWindowId,
    this.taskId,
  });

  final String id;
  final String tip;
  final String mesaj;
  final bool okundu;
  final DateTime? createdAt;
  final String? patrolWindowId;
  final String? taskId;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        tip: json['tip'] as String? ?? '',
        mesaj: json['mesaj'] as String? ?? '',
        okundu: json['okundu'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        patrolWindowId: json['patrol_window_id'] as String?,
        taskId: json['task_id'] as String?,
      );

  AppNotification copyWith({bool? okundu}) => AppNotification(
        id: id,
        tip: tip,
        mesaj: mesaj,
        okundu: okundu ?? this.okundu,
        createdAt: createdAt,
        patrolWindowId: patrolWindowId,
        taskId: taskId,
      );
}

/// Sayfali liste yaniti (NotificationListResponse) — `total` meta'dan
/// (okunmamis sayaci okundu=false + limit=1 sorgusunun total'idir).
class NotificationPage {
  const NotificationPage({required this.items, required this.total});

  final List<AppNotification> items;
  final int total;

  factory NotificationPage.fromJson(Map<String, dynamic> json) =>
      NotificationPage(
        total: ((json['meta'] as Map?)?['total'] as num?)?.toInt() ?? 0,
        items: [
          for (final item in (json['items'] as List?) ?? const [])
            if (item is Map)
              AppNotification.fromJson(Map<String, dynamic>.from(item)),
        ],
      );
}
