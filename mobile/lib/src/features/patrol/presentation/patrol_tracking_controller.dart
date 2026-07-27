import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/patrol_api.dart';
import '../domain/patrol_models.dart';
import '../domain/patrol_hata.dart';
import 'devriye_hata_metni.dart';

/// Yonetici "Devriye takibi — Bugun" sekmesinin durumu
/// (`GET /dashboard/live` → aktif_turlar; panelin canli ozeti ile ayni veri).
class PatrolTrackingState {
  const PatrolTrackingState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.forbidden = false,
    this.windows = const [],
    this.refreshedAt,
  });

  final bool loading;
  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. domain/*_hata.dart). Ekran once
  /// kimligi cozer (`*HatasiCoz`), yoksa sunucu metnini gosterir.
  final String? errorMessage;
  final DevriyeAkisHatasi? hataKimligi;
  final bool forbidden;

  /// Bugune ait pencereler (sunucu sirasi: pencere_baslangic ASC).
  final List<ActivePatrolWindow> windows;

  final DateTime? refreshedAt;

  PatrolTrackingState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    bool? forbidden,
    List<ActivePatrolWindow>? windows,
    DateTime? refreshedAt,
  }) {
    return PatrolTrackingState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as DevriyeAkisHatasi?,
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
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      final windows = await ref.read(patrolApiProvider).fetchLiveWindows();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        forbidden: false,
        windows: windows,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        hataKimligi: devriyeAgHatasi(e),
        forbidden: e.statusCode == 403,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: DevriyeAkisHatasi.beklenmeyen,
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
