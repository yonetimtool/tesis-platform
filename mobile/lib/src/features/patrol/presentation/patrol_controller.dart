import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../scan/data/scan_outbox.dart';
import '../data/patrol_api.dart';
import '../domain/patrol_models.dart';

/// "Turlarim" aktif sekmesinin durumu: aktif/siradaki pencere + nokta listesi.
class PatrolTourState {
  const PatrolTourState({
    this.loading = false,
    this.errorMessage,
    this.forbidden = false,
    this.active,
    this.next,
    this.checkpoints = const [],
    this.refreshedAt,
  });

  /// Ilk yukleme / manuel yenileme devam ediyor mu (sessiz otomatik yenileme
  /// bu bayragi ACMAZ — ekran titremesin).
  final bool loading;

  /// Son yenilemenin kullaniciya gosterilecek hatasi (varsa). Eldeki veri
  /// silinmez; bayat veri + hata bandi birlikte gosterilebilir.
  final String? errorMessage;

  /// 403 — rol bu uca erisemiyor (guvenlik disi roller icin kibar mesaj).
  final bool forbidden;

  /// Su an icinde bulundugumuz pencere (yoksa null → "aktif devriye yok").
  final ActivePatrolWindow? active;

  /// Bir sonraki bekleyen pencere (bilgi amacli).
  final ActivePatrolWindow? next;

  /// Aktif pencerenin nokta listesi — sunucu plan verisi + BU CIHAZIN yerel
  /// okutma kaydinin birlesimi (bkz. mergeCheckpointStatuses).
  final List<CheckpointStatus> checkpoints;

  final DateTime? refreshedAt;

  /// Bu cihazin isaretledigi nokta sayisi (okutuldu + gonderiliyor).
  int get localOkutulan => checkpoints.where((c) => c.okundu).length;

  /// Ilerleme payi: sunucu sayisi (tum cihazlar) ile yerel isaretin buyugu —
  /// offline'da bile kullanicinin kendi ilerlemesi geri gitmez.
  int get okutulanBirlesik =>
      math.max(active?.okutulanCheckpointSayisi ?? 0, localOkutulan);

  int get beklenen =>
      active?.beklenenCheckpointSayisi == 0 && checkpoints.isNotEmpty
          ? checkpoints.length
          : active?.beklenenCheckpointSayisi ?? checkpoints.length;

  PatrolTourState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    bool? forbidden,
    Object? active = _sentinel,
    Object? next = _sentinel,
    List<CheckpointStatus>? checkpoints,
    DateTime? refreshedAt,
  }) {
    return PatrolTourState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      forbidden: forbidden ?? this.forbidden,
      active: active == _sentinel ? this.active : active as ActivePatrolWindow?,
      next: next == _sentinel ? this.next : next as ActivePatrolWindow?,
      checkpoints: checkpoints ?? this.checkpoints,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Aktif tur controller'i:
///
///   * `GET /dashboard/live` ile aktif/siradaki pencereyi bulur,
///   * aktif pencerenin planindan nokta listesini ceker (plan degismedikce
///     tekrar cekmez),
///   * outbox degisimlerini dinler → nokta durumlarini AG'A CIKMADAN yeniden
///     birlestirir (offline'da bile ✓ aninda gorunur),
///   * 60 sn'de bir sessiz otomatik yenileme yapar (pull-to-refresh ayrica).
class PatrolTourController extends Notifier<PatrolTourState> {
  Timer? _autoRefresh;

  /// Aktif planin sunucudan gelen ham nokta listesi (birlesim girdisi).
  List<PlanCheckpoint> _planCheckpoints = const [];
  String? _loadedPlanId;
  bool _refreshing = false;

  static const _autoRefreshInterval = Duration(seconds: 60);

  @override
  PatrolTourState build() {
    ref.onDispose(() => _autoRefresh?.cancel());
    _autoRefresh = Timer.periodic(
      _autoRefreshInterval,
      (_) => refresh(silent: true),
    );
    // Outbox degisince (yeni okutma / gonderim sonucu) yerel birlesimi tazele.
    ref.listen(
      scanOutboxProvider.select((s) => s.entries),
      (_, _) => _remergeFromOutbox(),
    );
    Future.microtask(refresh);
    return const PatrolTourState(loading: true);
  }

  PatrolApi get _api => ref.read(patrolApiProvider);

  /// Sunucudan tam yenileme. [silent] otomatik yenilemede spinner acilmaz;
  /// hata da sessizce mevcut verinin ustune yazilmaz (bayat veri kalir).
  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      state = state.copyWith(loading: true, errorMessage: null);
    }
    try {
      final windows = await _api.fetchLiveWindows();
      if (!ref.mounted) return;

      final now = DateTime.now().toUtc();
      final active = _earliest(windows.where((w) => w.isActiveAt(now)));
      final next = _earliest(windows.where((w) => w.isUpcomingAt(now)));

      if (active == null) {
        _planCheckpoints = const [];
        _loadedPlanId = null;
      } else if (_loadedPlanId != active.patrolPlanId) {
        _planCheckpoints = await _api.fetchPlanCheckpoints(active.patrolPlanId);
        if (!ref.mounted) return;
        _loadedPlanId = active.patrolPlanId;
      }

      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        active: active,
        next: next,
        checkpoints: _merge(active),
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

  /// Outbox degisiminde ag cagrisi YAPMADAN nokta durumlarini gunceller.
  void _remergeFromOutbox() {
    final active = state.active;
    if (active == null || _planCheckpoints.isEmpty) return;
    state = state.copyWith(checkpoints: _merge(active));
  }

  List<CheckpointStatus> _merge(ActivePatrolWindow? active) {
    if (active == null) return const [];
    return mergeCheckpointStatuses(
      checkpoints: _planCheckpoints,
      pencereBaslangic: active.pencereBaslangic,
      pencereBitis: active.pencereBitis,
      outboxEntries: ref.read(scanOutboxProvider).entries,
    );
  }

  ActivePatrolWindow? _earliest(Iterable<ActivePatrolWindow> windows) {
    ActivePatrolWindow? best;
    for (final w in windows) {
      if (best == null || w.pencereBaslangic.isBefore(best.pencereBaslangic)) {
        best = w;
      }
    }
    return best;
  }
}

final patrolTourControllerProvider =
    NotifierProvider<PatrolTourController, PatrolTourState>(
  PatrolTourController.new,
);
