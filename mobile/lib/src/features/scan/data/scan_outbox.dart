import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/outbox_entry.dart';
import '../domain/scan.dart';
import 'scan_api.dart';
import 'scan_outbox_store.dart';

/// Outbox'in anlik gorunumu: kalici kuyruk + senkron bayragi.
class ScanOutboxState {
  const ScanOutboxState({
    this.entries = const [],
    this.loaded = false,
    this.syncing = false,
  });

  /// FIFO sirali kuyruk (basta en eski). `gonderildi` kayitlarin son birkaci
  /// UI geri bildirimi icin tutulur, gerisi budanir.
  final List<OutboxEntry> entries;

  /// Kalici depo okundu mu (okunana kadar pump calismaz).
  final bool loaded;

  /// Su anda bir gonderim turu (pump) calisiyor mu.
  final bool syncing;

  int get pendingCount => entries.where((e) => e.isPending).length;
  int get failedCount =>
      entries.where((e) => e.status == OutboxStatus.kaliciHata).length;

  OutboxEntry? byKey(String idempotencyKey) {
    for (final e in entries) {
      if (e.idempotencyKey == idempotencyKey) return e;
    }
    return null;
  }

  ScanOutboxState copyWith({
    List<OutboxEntry>? entries,
    bool? loaded,
    bool? syncing,
  }) =>
      ScanOutboxState(
        entries: entries ?? this.entries,
        loaded: loaded ?? this.loaded,
        syncing: syncing ?? this.syncing,
      );
}

/// Kalici offline kuyruk + senkron motoru ("en az bir kez gonder").
///
/// Durum makinesi: bekliyor → gonderiliyor → gonderildi (201/200)
///                                       ↘ bekliyor (ag/5xx/auth — backoff'lu retry)
///                                       ↘ kalici_hata (404 vb. — retry yok)
///
/// Cift gonderim riski yok: Idempotency-Key okuma aninda sabitlendigi icin
/// backend tekrarlari 200 + mevcut kayit ile yutar.
class ScanOutbox extends Notifier<ScanOutboxState> {
  Timer? _retryTimer;
  int _consecutiveFailures = 0;
  bool _pumping = false;
  bool _pumpAgain = false;

  /// `gonderildi` kayitlardan en fazla bu kadari tutulur (UI geri bildirimi
  /// icin); eskiler budanir ki dosya sinirsiz buyumesin.
  static const _maxSentKept = 20;

  /// Backoff: 15s * 2^(ardisik hata - 1), tavan 10 dk. Bag geldiginde /
  /// manuel senkronda sayac sifirlanir → beklemeden dener.
  static const _baseBackoff = Duration(seconds: 15);
  static const _maxBackoff = Duration(minutes: 10);

  @override
  ScanOutboxState build() {
    ref.onDispose(() => _retryTimer?.cancel());
    Future.microtask(_init);
    return const ScanOutboxState();
  }

  ScanOutboxStore get _store => ref.read(scanOutboxStoreProvider);

  Future<void> _init() async {
    final loaded = await _store.load();
    if (!ref.mounted) return;
    // Cokme kurtarma: gonderim ortasinda olduysek sonucu bilmiyoruz →
    // idempotency-key sayesinde yeniden gondermek guvenli, bekliyor'a al.
    var recoveredAny = false;
    final recovered = <OutboxEntry>[];
    for (final e in loaded) {
      if (e.status == OutboxStatus.gonderiliyor) {
        recoveredAny = true;
        recovered.add(e.copyWith(status: OutboxStatus.bekliyor));
      } else {
        recovered.add(e);
      }
    }
    state = state.copyWith(entries: recovered, loaded: true);
    if (recoveredAny) await _persist();
    unawaited(pump());
  }

  /// Yeni okutmayi KALICI kuyruga yazar (once disk, sonra pump). Ayni
  /// idempotency-key zaten kuyruktaysa ikinci kez eklenmez.
  Future<void> enqueue(ScanDraft draft) async {
    if (!state.loaded) await _waitUntilLoaded();
    if (!ref.mounted) return;
    if (state.byKey(draft.idempotencyKey) != null) {
      unawaited(pump());
      return;
    }
    final entry = OutboxEntry.fromDraft(draft, now: DateTime.now());
    state = state.copyWith(entries: [...state.entries, entry]);
    await _persist();
    unawaited(pump());
  }

  /// Manuel "simdi senkronla": backoff sayacini sifirlar ve hemen dener.
  Future<void> syncNow() {
    _consecutiveFailures = 0;
    _retryTimer?.cancel();
    return pump();
  }

  /// Bekleyen kayitlari SIRAYLA (FIFO) gonderir. Ag benzeri gecici hatada
  /// turu keser ve ustel geri cekilme ile yeniden dener; kalici hatada
  /// (404 vb.) kaydi ayirir ve siradakiyle devam eder.
  Future<void> pump() async {
    if (!state.loaded || _pumping) {
      _pumpAgain = _pumping;
      return;
    }
    _pumping = true;
    _retryTimer?.cancel();
    state = state.copyWith(syncing: true);
    try {
      while (ref.mounted) {
        OutboxEntry? next;
        for (final e in state.entries) {
          if (e.status == OutboxStatus.bekliyor) {
            next = e;
            break;
          }
        }
        if (next == null) break;

        _replace(next.copyWith(status: OutboxStatus.gonderiliyor));
        await _persist();
        if (!ref.mounted) return;

        try {
          final result = await ref.read(scanApiProvider).submit(next.toDraft());
          if (!ref.mounted) return;
          _consecutiveFailures = 0;
          _replace(next.copyWith(
            status: OutboxStatus.gonderildi,
            attemptCount: next.attemptCount + 1,
            lastError: null,
            outcome: result.wasDuplicate
                ? OutboxOutcome.duplicate
                : OutboxOutcome.created,
          ));
          await _persist();
        } on ApiException catch (e) {
          if (!ref.mounted) return;
          if (_isPermanent(e)) {
            // Etiket sistemde yok vb. — tekrar gondermek anlamsiz.
            _replace(next.copyWith(
              status: OutboxStatus.kaliciHata,
              attemptCount: next.attemptCount + 1,
              lastError: permanentErrorMessage(e),
            ));
            await _persist();
            continue; // siradaki kayit denenebilir
          }
          // Ag / timeout / 5xx / auth (refresh olu) → bekliyor kalir,
          // sonra tekrar denenir. Tur kesilir: baglanti yoksa siradakiler
          // de basarisiz olur, pil/veri bosa harcanmasin.
          await _markRetry(next, e.message);
          break;
        } catch (e) {
          if (!ref.mounted) return;
          await _markRetry(next, 'Beklenmeyen hata: $e');
          break;
        }
      }
    } finally {
      _pumping = false;
      if (ref.mounted) {
        state = state.copyWith(syncing: false);
        if (_pumpAgain) {
          _pumpAgain = false;
          unawaited(pump());
        }
      }
    }
  }

  /// Kalici hatalari (404 vb.) kuyruktan temizler.
  Future<void> clearFailed() async {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.status != OutboxStatus.kaliciHata) e,
      ],
    );
    await _persist();
  }

  bool _isPermanent(ApiException e) =>
      // 404: etiket eslesmedi. 400/422: govde gecersiz — payload degismeyecegi
      // icin tekrar denemek de ayni sonucu verir. NTAG424 SDM 422'leri
      // (invalid_signature/replay_detected) da bu siniftadir: etiket verisi
      // sabit, tekrar gonderim sonucu degistirmez.
      e.statusCode == 404 || e.statusCode == 400 || e.statusCode == 422;

  Future<void> _markRetry(OutboxEntry entry, String message) async {
    _replace(entry.copyWith(
      status: OutboxStatus.bekliyor,
      attemptCount: entry.attemptCount + 1,
      lastError: message,
    ));
    await _persist();
    _consecutiveFailures++;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    final exp = math.min(_consecutiveFailures - 1, 10);
    final delayMs = math.min(
      _baseBackoff.inMilliseconds * math.pow(2, exp).toInt(),
      _maxBackoff.inMilliseconds,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(pump());
    });
  }

  void _replace(OutboxEntry updated) {
    state = state.copyWith(entries: [
      for (final e in state.entries)
        e.idempotencyKey == updated.idempotencyKey ? updated : e,
    ]);
  }

  Future<void> _persist() async {
    // gonderildi kayitlarin yalnizca en yeni _maxSentKept tanesini tut.
    final entries = state.entries;
    final sent = entries
        .where((e) => e.status == OutboxStatus.gonderildi)
        .toList();
    var pruned = entries;
    if (sent.length > _maxSentKept) {
      final drop = sent.take(sent.length - _maxSentKept).toSet();
      pruned = [
        for (final e in entries)
          if (!drop.contains(e)) e,
      ];
      state = state.copyWith(entries: pruned);
    }
    await _store.save(pruned);
  }

  Future<void> _waitUntilLoaded() async {
    while (ref.mounted && !state.loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

/// Kalici hatanin kullaniciya gosterilecek Turkce karsiligi. NTAG424 SDM
/// dogrulama kodlari icin ozel mesajlar; digerlerinde backend mesaji aynen
/// kalir (404 zaten Turkce donuyor).
String permanentErrorMessage(ApiException e) => switch (e.code) {
      'invalid_signature' =>
        'Etiket imzası doğrulanamadı — sahte veya yanlış etiket olabilir.',
      'replay_detected' => 'Bu okutma daha önce işlendi.',
      _ => e.message,
    };

final scanOutboxProvider =
    NotifierProvider<ScanOutbox, ScanOutboxState>(ScanOutbox.new);

/// Otomatik senkron tetikleyicileri. Uygulama kokunde watch edilir; su
/// durumlarda pump'i tetikler:
///   * baglanti geri gelince (connectivity_plus akisi),
///   * uygulama one gelince (AppLifecycleListener.onResume),
///   * login basarili olunca (bekleyenler auth hatasiyla kalmis olabilir).
/// (Yeni scan eklenince tetikleme enqueue icinde; manuel buton UI'da.)
final outboxAutoSyncProvider = Provider<void>((ref) {
  final connSub = Connectivity().onConnectivityChanged.listen((results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      unawaited(ref.read(scanOutboxProvider.notifier).syncNow());
    }
  });

  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(ref.read(scanOutboxProvider.notifier).syncNow()),
  );

  ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
    if (next == AuthStatus.authenticated) {
      unawaited(ref.read(scanOutboxProvider.notifier).syncNow());
    }
  });

  ref.onDispose(() {
    connSub.cancel();
    lifecycle.dispose();
  });
});
