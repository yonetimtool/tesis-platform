import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../scan/data/scan_outbox.dart';
import '../../scan/domain/outbox_entry.dart';
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
    this.windows = const [],
    this.selectedWindowId,
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

  /// Gosterilen aktif pencere (yoksa null → "aktif devriye yok"). Birden cok
  /// aktif pencere varsa kullanicinin sectigi; varsayilan bitisi en yakin
  /// (sunucunun `window` alani).
  final ActivePatrolWindow? active;

  /// Bir sonraki bekleyen pencere (bilgi amacli, /dashboard/live'dan).
  final ActivePatrolWindow? next;

  /// Gosterilen pencerenin nokta listesi — SUNUCU okutma durumu
  /// (GET /me/patrol-window, pencere-geneli) + bu cihazin outbox'ta bekleyen
  /// okutmalarinin bindirmesi (bkz. mergeCheckpointStatuses).
  final List<CheckpointStatus> checkpoints;

  /// TUM aktif pencereler (pencere_bitis ASC). 1'den fazlaysa ekran basit
  /// bir pencere secici gosterir.
  final List<ActivePatrolWindow> windows;

  /// [windows] icinden gosterilen pencerenin id'si (varsa).
  final String? selectedWindowId;

  final DateTime? refreshedAt;

  /// Listede isaretli gorunen nokta sayisi (okutuldu + gonderiliyor) —
  /// sunucu ✓'leri ile bu cihazin bekleyen okutmalarinin toplami.
  int get localOkutulan => checkpoints.where((c) => c.okundu).length;

  /// Ilerleme payi: sunucu sayisi ile listedeki isaretin buyugu — outbox'ta
  /// bekleyen okutmalar sunucu sayisina henuz yansimadiginda ilerleme geri
  /// gitmez (offline dahil).
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
    List<ActivePatrolWindow>? windows,
    Object? selectedWindowId = _sentinel,
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
      windows: windows ?? this.windows,
      selectedWindowId: selectedWindowId == _sentinel
          ? this.selectedWindowId
          : selectedWindowId as String?,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Aktif tur controller'i:
///
///   * `GET /me/patrol-window` ile aktif pencere(ler)i ve checkpoint bazinda
///     SUNUCU okutma durumunu ceker (baska elemanin okutmasi da gorunur),
///   * `GET /dashboard/live` ile yalnizca SIRADAKI pencereyi bulur (bilgi
///     karti; basarisiz olursa eldeki deger korunur — ana akisi engellemez),
///   * secili planin nokta listesini UID haritasi icin ceker (outbox
///     kayitlari cogunlukla checkpoint_id tasimaz; plan degismedikce tekrar
///     cekmez, basarisizligi bindirmeyi zayiflatir ama ekrani BOZMAZ),
///   * outbox degisimlerini dinler → bekleyen okutmalari AG'A CIKMADAN
///     sunucu verisinin uzerine bindirir (offline'da bile ✓ aninda gorunur);
///     bir gonderim TAMAMLANINCA sunucu verisini sessizce tazeler
///     ("gonderiliyor" → sunucu ✓'sine gecis geri adim gorunmesin),
///   * 60 sn'de bir sessiz otomatik yenileme yapar (pull-to-refresh ayrica).
class PatrolTourController extends Notifier<PatrolTourState> {
  Timer? _autoRefresh;

  /// Son basarili `GET /me/patrol-window` yanitindaki aktif pencereler.
  List<MePatrolWindowItem> _serverWindows = const [];

  /// Kullanicinin sectigi pencere (null → sunucunun varsayilani: en acil).
  String? _selectedWindowId;

  /// Secili planin nokta listesi — yalnizca NFC UID haritasi icin
  /// (outbox bindirmesinin eslestirme anahtari).
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
    // Outbox degisince bekleyen okutma bindirmesini ag'a cikmadan tazele;
    // bir kayit gonderildiyse sunucu ✓'sini yetistirmek icin sessiz yenile.
    ref.listen(
      scanOutboxProvider.select((s) => s.entries),
      (prev, next) {
        _overlayFromOutbox();
        if (_sendCompleted(prev, next)) {
          Future.microtask(() => refresh(silent: true));
        }
      },
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
      final me = await _api.fetchMyPatrolWindow();
      if (!ref.mounted) return;
      _serverWindows = me.windows;

      // Siradaki pencere yalnizca bilgi kartidir; /dashboard/live dusse bile
      // ana akis (aktif tur listesi) calismaya devam eder.
      var next = state.next;
      try {
        final live = await _api.fetchLiveWindows();
        if (!ref.mounted) return;
        final now = DateTime.now().toUtc();
        next = _earliest(live.where((w) => w.isUpcomingAt(now)));
      } on ApiException {
        // Eldeki "siradaki" bilgisi korunur.
      }

      final selected = _selectedItem();
      await _ensureUidMap(selected);
      if (!ref.mounted) return;

      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        active: selected?.toActiveWindow(),
        next: next,
        checkpoints: _overlay(selected),
        windows: [for (final w in _serverWindows) w.toActiveWindow()],
        selectedWindowId: selected?.id,
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

  /// Birden cok aktif pencere varken gosterilen pencereyi degistirir.
  /// Ag cagrisi gerekmez (veri zaten elde); yalnizca farkli bir planin UID
  /// haritasi eksikse o cekilir.
  Future<void> selectWindow(String windowId) async {
    if (windowId == _selectedWindowId) return;
    _selectedWindowId = windowId;
    final selected = _selectedItem();
    await _ensureUidMap(selected);
    if (!ref.mounted) return;
    state = state.copyWith(
      active: selected?.toActiveWindow(),
      checkpoints: _overlay(selected),
      selectedWindowId: selected?.id,
    );
  }

  /// Gosterilecek pencere: kullanici secimi hala aktifse o; degilse sunucu
  /// varsayilani (windows[] `pencere_bitis` ASC geldigi icin ilk oge =
  /// bitisi en yakin pencere, yani yanittaki `window`).
  MePatrolWindowItem? _selectedItem() {
    if (_serverWindows.isEmpty) {
      _selectedWindowId = null;
      return null;
    }
    for (final w in _serverWindows) {
      if (w.id == _selectedWindowId) return w;
    }
    _selectedWindowId = null;
    return _serverWindows.first;
  }

  /// Secili planin UID haritasini hazirlar (plan degismedikce tekrar cekmez).
  /// Basarisizlik bindirmeyi checkpoint_id eslesmesine dusurur; ekran sunucu
  /// verisiyle calismaya devam eder.
  Future<void> _ensureUidMap(MePatrolWindowItem? selected) async {
    if (selected == null) {
      _planCheckpoints = const [];
      _loadedPlanId = null;
      return;
    }
    if (_loadedPlanId == selected.patrolPlanId) return;
    try {
      _planCheckpoints = await _api.fetchPlanCheckpoints(selected.patrolPlanId);
      _loadedPlanId = selected.patrolPlanId;
    } on ApiException {
      _planCheckpoints = const [];
      _loadedPlanId = null;
    }
  }

  /// Outbox degisiminde ag cagrisi YAPMADAN bekleyen bindirmesini gunceller.
  void _overlayFromOutbox() {
    final selected = _selectedItem();
    if (selected == null) return;
    state = state.copyWith(checkpoints: _overlay(selected));
  }

  List<CheckpointStatus> _overlay(MePatrolWindowItem? selected) {
    if (selected == null) return const [];
    return mergeCheckpointStatuses(
      serverCheckpoints: selected.checkpoints,
      pencereBaslangic: selected.pencereBaslangic,
      pencereBitis: selected.pencereBitis,
      outboxEntries: ref.read(scanOutboxProvider).entries,
      uidByCheckpointId: {
        for (final cp in _planCheckpoints)
          if (cp.nfcTagUid != null) cp.checkpointId: cp.nfcTagUid!,
      },
    );
  }

  /// Onceki listede bekleyen bir kayit yeni listede `gonderildi` olduysa true
  /// (backend kabul etti → sunucu ✓'sini cekme zamani).
  bool _sendCompleted(List<OutboxEntry>? prev, List<OutboxEntry> next) {
    if (prev == null) return false;
    final wasPending = <String>{
      for (final e in prev)
        if (e.isPending) e.idempotencyKey,
    };
    return next.any(
      (e) =>
          e.status == OutboxStatus.gonderildi &&
          wasPending.contains(e.idempotencyKey),
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
