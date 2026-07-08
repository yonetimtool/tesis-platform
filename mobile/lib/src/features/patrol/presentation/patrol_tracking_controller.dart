import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/patrol_api.dart';
import '../domain/patrol_models.dart';

/// Yonetici "Devriye takibi — Bugun" sekmesinin durumu
/// (`GET /dashboard/live` → aktif_turlar; panelin canli ozeti ile ayni veri).
class PatrolTrackingState {
  const PatrolTrackingState({
    this.loading = false,
    this.errorMessage,
    this.forbidden = false,
    this.windows = const [],
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;
  final bool forbidden;

  /// Bugune ait pencereler (sunucu sirasi: pencere_baslangic ASC).
  final List<ActivePatrolWindow> windows;

  final DateTime? refreshedAt;

  PatrolTrackingState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    bool? forbidden,
    List<ActivePatrolWindow>? windows,
    DateTime? refreshedAt,
  }) {
    return PatrolTrackingState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      forbidden: forbidden ?? this.forbidden,
      windows: windows ?? this.windows,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

class PatrolTrackingController extends Notifier<PatrolTrackingState> {
  bool _refreshing = false;

  @override
  PatrolTrackingState build() {
    Future.microtask(refresh);
    return const PatrolTrackingState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final windows = await ref.read(patrolApiProvider).fetchLiveWindows();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        windows: windows,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        forbidden: e.statusCode == 403,
      );
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
}

final patrolTrackingControllerProvider =
    NotifierProvider<PatrolTrackingController, PatrolTrackingState>(
  PatrolTrackingController.new,
);
