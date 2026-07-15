import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/visitor_api.dart';
import '../domain/visitor_models.dart';

/// Ziyaretci listesinin durumu.
class VisitorsState {
  const VisitorsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.canRegister = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Sunucu sirasi: created_at DESC (en yeni onde). Ziyaretci LOG kayitlaridir
  /// (onay/red yok). Sakin icin sunucu zaten YALNIZ kendine hedeflenen
  /// kayitlari doner.
  final List<Visitor> items;

  /// Rol security mi — "Yeni ziyaretci" FAB'i. Yalniz UX kapisi; gercek
  /// yetki backend RBAC'ta.
  final bool canRegister;

  final DateTime? refreshedAt;

  VisitorsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Visitor>? items,
    bool? canRegister,
    DateTime? refreshedAt,
  }) {
    return VisitorsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canRegister: canRegister ?? this.canRegister,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Ziyaretci LOG listesi controller'i. Kayit basarili olunca listeyi tazeler;
/// hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException yukari firlatilir).
class VisitorsController extends Notifier<VisitorsState> {
  bool _refreshing = false;

  @override
  VisitorsState build() {
    Future.microtask(refresh);
    return const VisitorsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(visitorApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canRegister: role.canRegisterVisitor,
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

  Future<void> register(VisitorDraft draft) async {
    await ref.read(visitorApiProvider).create(draft);
    await refresh();
  }

  /// Guvenlik mevcut ziyaretci kaydini duzenler (ad/daire/hedef/not).
  Future<void> update(
    String id, {
    required String ziyaretciAd,
    required String unitNo,
    required String targetResidentUserId,
    String? notlar,
  }) async {
    await ref.read(visitorApiProvider).update(
          id,
          ziyaretciAd: ziyaretciAd,
          unitNo: unitNo,
          targetResidentUserId: targetResidentUserId,
          notlar: notlar,
        );
    await refresh();
  }
}

final visitorsControllerProvider =
    NotifierProvider<VisitorsController, VisitorsState>(
  VisitorsController.new,
);
