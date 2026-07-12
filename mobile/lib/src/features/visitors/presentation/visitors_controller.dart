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
    this.canAnswer = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Sunucu sirasi: created_at DESC (en yeni onde). Sakin icin sunucu zaten
  /// YALNIZ kendi dairesinin kayitlarini doner.
  final List<Visitor> items;

  /// Rol security mi — "Yeni ziyaretci" FAB'i. Yalniz UX kapisi; gercek
  /// yetki backend RBAC'ta.
  final bool canRegister;

  /// Rol resident mi — bekleyen kartta Onayla/Reddet butonlari (dairenin
  /// sakini olma kosulunu sunucu ayrica zorlar).
  final bool canAnswer;

  final DateTime? refreshedAt;

  /// Bekleyenler one alinir (kapida cevap bekleyen kayit gomulmesin);
  /// gruplar kendi icinde sunucu sirasini (DESC) korur.
  List<Visitor> get sirali => [
        ...items.where((v) => v.bekliyor),
        ...items.where((v) => !v.bekliyor),
      ];

  VisitorsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Visitor>? items,
    bool? canRegister,
    bool? canAnswer,
    DateTime? refreshedAt,
  }) {
    return VisitorsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canRegister: canRegister ?? this.canRegister,
      canAnswer: canAnswer ?? this.canAnswer,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Ziyaretci listesi controller'i. Kayit/yanit eylemleri basarili olunca
/// listeyi tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir
/// (ApiException yukari firlatilir — orn. ikinci yanit 409'u).
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
        canAnswer: role.canAnswerVisitor,
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

  Future<void> answer(String id, {required bool onayla}) async {
    try {
      await ref.read(visitorApiProvider).answer(id, onayla: onayla);
    } finally {
      // 409 (baska sakin once yanitladi) durumunda da guncel durumu cek —
      // kartta dogru sonuc gorunsun; hata yine cagirana firlar.
      await refresh();
    }
  }
}

final visitorsControllerProvider =
    NotifierProvider<VisitorsController, VisitorsState>(
  VisitorsController.new,
);
