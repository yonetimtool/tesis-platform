import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/complaint_api.dart';
import '../domain/complaint_models.dart';

/// Talep listesinin durumu.
class ComplaintsState {
  const ComplaintsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.canCreate = false,
    this.canRespond = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Sunucu sirasi: created_at DESC (en yeni onde). Acan roller icin sunucu
  /// zaten YALNIZ kendi actiklarini doner.
  final List<Complaint> items;

  /// Acan rol mu (security/tesis_gorevlisi/resident) — "Yeni talep" FAB'i.
  /// Yalniz UX kapisi; gercek yetki backend RBAC'ta.
  final bool canCreate;

  /// Rol admin/yonetici mi — yanit/durum formu.
  final bool canRespond;

  final DateTime? refreshedAt;

  ComplaintsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Complaint>? items,
    bool? canCreate,
    bool? canRespond,
    DateTime? refreshedAt,
  }) {
    return ComplaintsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canCreate: canCreate ?? this.canCreate,
      canRespond: canRespond ?? this.canRespond,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Talep listesi controller'i. Ac/yanitla eylemleri basarili olunca listeyi
/// tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException
/// yukari firlatilir).
class ComplaintsController extends Notifier<ComplaintsState> {
  bool _refreshing = false;

  @override
  ComplaintsState build() {
    Future.microtask(refresh);
    return const ComplaintsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(complaintApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canCreate: role.canCreateComplaint,
        canRespond: role.canRespondComplaints,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> create(ComplaintDraft draft) async {
    await ref.read(complaintApiProvider).create(draft);
    await refresh();
  }

  Future<void> reply(String id, ComplaintReplyDraft draft) async {
    await ref.read(complaintApiProvider).reply(id, draft);
    await refresh();
  }
}

final complaintsControllerProvider =
    NotifierProvider<ComplaintsController, ComplaintsState>(
  ComplaintsController.new,
);
