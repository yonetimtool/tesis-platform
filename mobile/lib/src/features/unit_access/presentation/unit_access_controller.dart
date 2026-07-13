import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/unit_access_api.dart';
import '../domain/unit_access_models.dart';

/// Tek-seferlik daire erisim izni listesinin durumu (rol-uyarlamali).
class UnitAccessState {
  const UnitAccessState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.canRequest = false,
    this.canDecide = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;
  final List<UnitAccessRequest> items;

  /// admin/yonetici — "Yeni istek" (talep acma).
  final bool canRequest;

  /// resident — gelen talebi Onayla/Reddet.
  final bool canDecide;

  final DateTime? refreshedAt;

  /// Bekleyenler one alinir (karar bekleyen gomulmesin).
  List<UnitAccessRequest> get sirali => [
        ...items.where((r) => r.bekliyor),
        ...items.where((r) => !r.bekliyor),
      ];

  UnitAccessState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<UnitAccessRequest>? items,
    bool? canRequest,
    bool? canDecide,
    DateTime? refreshedAt,
  }) {
    return UnitAccessState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      canRequest: canRequest ?? this.canRequest,
      canDecide: canDecide ?? this.canDecide,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

class UnitAccessController extends Notifier<UnitAccessState> {
  bool _refreshing = false;

  @override
  UnitAccessState build() {
    Future.microtask(refresh);
    return const UnitAccessState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(unitAccessApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canRequest: role.canRequestUnitAccess,
        canDecide: role.canDecideUnitAccess,
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

  /// Talep ac (admin/yonetici) — basari/hata cagirana firlatilir (form gosterir).
  Future<void> createRequest(String unitNo) async {
    await ref.read(unitAccessApiProvider).createRequest(unitNo);
    await refresh();
  }

  Future<void> decide(String id, {required bool onayla}) async {
    try {
      await ref.read(unitAccessApiProvider).decide(id, onayla: onayla);
    } finally {
      await refresh();
    }
  }
}

final unitAccessControllerProvider =
    NotifierProvider<UnitAccessController, UnitAccessState>(
  UnitAccessController.new,
);
