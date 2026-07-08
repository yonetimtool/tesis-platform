import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/announcement_api.dart';
import '../domain/announcement_models.dart';

/// Duyuru listesinin durumu.
class AnnouncementsState {
  const AnnouncementsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.canManage = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Sunucu sirasi: created_at DESC (en yeni onde).
  final List<Announcement> items;

  /// Rol admin/yonetici mi — yeni duyuru FAB'i + duzenle/sil menusu.
  /// Yalniz UX kapisi; gercek yetki backend RBAC'ta.
  final bool canManage;

  final DateTime? refreshedAt;

  AnnouncementsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Announcement>? items,
    bool? canManage,
    DateTime? refreshedAt,
  }) {
    return AnnouncementsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canManage: canManage ?? this.canManage,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Duyuru listesi controller'i. Olustur/duzenle/sil eylemleri basarili
/// olunca listeyi tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir
/// (ApiException yukari firlatilir).
class AnnouncementsController extends Notifier<AnnouncementsState> {
  bool _refreshing = false;

  @override
  AnnouncementsState build() {
    Future.microtask(refresh);
    return const AnnouncementsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(announcementApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canManage: role.canManageAnnouncements,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> create(AnnouncementDraft draft) async {
    await ref.read(announcementApiProvider).create(draft);
    await refresh();
  }

  Future<void> update(String id, AnnouncementDraft draft) async {
    await ref.read(announcementApiProvider).update(id, draft);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(announcementApiProvider).delete(id);
    await refresh();
  }
}

final announcementsControllerProvider =
    NotifierProvider<AnnouncementsController, AnnouncementsState>(
  AnnouncementsController.new,
);
