import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/patrol_api.dart';
import '../domain/patrol_models.dart';
import '../domain/patrol_hata.dart';
import 'devriye_hata_metni.dart';

/// "Gecmis" sekmesinin durumu: son pencereler + ozet sayilar.
class PatrolHistoryState {
  const PatrolHistoryState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.forbidden = false,
    this.items = const [],
    this.ozet = const PatrolWindowOzet(),
    this.aralik,
  });

  /// (P253 Asama 1) Secili tarih araligi (gun, iki uc dahil); null = son
  /// pencereler (bugunden once).
  final DateTimeRange? aralik;

  final bool loading;
  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. domain/*_hata.dart). Ekran once
  /// kimligi cozer (`*HatasiCoz`), yoksa sunucu metnini gosterir.
  final String? errorMessage;
  final DevriyeAkisHatasi? hataKimligi;
  final bool forbidden;
  final List<PatrolWindowHistoryItem> items;
  final PatrolWindowOzet ozet;

  PatrolHistoryState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    bool? forbidden,
    List<PatrolWindowHistoryItem>? items,
    PatrolWindowOzet? ozet,
    Object? aralik = _sentinel,
  }) {
    return PatrolHistoryState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as DevriyeAkisHatasi?,
      forbidden: forbidden ?? this.forbidden,
      items: items ?? this.items,
      ozet: ozet ?? this.ozet,
      aralik: aralik == _sentinel ? this.aralik : aralik as DateTimeRange?,
    );
  }

  static const Object _sentinel = Object();
}

/// Pencere gecmisi (`GET /patrol-windows`, pencere_baslangic DESC). Basit
/// tek-sayfa liste: son [_pageSize] pencere yeterli (tam sayfalama panelde).
class PatrolHistoryController extends Notifier<PatrolHistoryState> {
  static const _pageSize = 50;

  @override
  PatrolHistoryState build() {
    Future.microtask(refresh);
    return const PatrolHistoryState(loading: true);
  }

  /// (P253 Asama 1) Tarih araligini ayarla (null = temizle) ve tazele.
  Future<void> aralikSec(DateTimeRange? aralik) async {
    state = state.copyWith(aralik: aralik);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      // Gecmis = YALNIZ gecmis: bugunun turlari "Aktif"/"Bugun"da; burada
      // yalniz bugunden ONCE baslayan pencereler.
      final now = DateTime.now();
      final bugunBasi = DateTime(now.year, now.month, now.day);
      // (P253 Asama 1) ARALIK: [ilk gun 00:00, son gunun ertesi 00:00);
      // ust sinir yine BUGUNDEN ONCE (bugun "Aktif"/"Bugun" sekmesinde).
      final a = state.aralik;
      final sonrakiGun = a == null
          ? bugunBasi
          : DateTime(a.end.year, a.end.month, a.end.day + 1);
      final page = await ref.read(patrolApiProvider).fetchWindowHistory(
            limit: _pageSize,
            bitisBefore: sonrakiGun.isBefore(bugunBasi) ? sonrakiGun : bugunBasi,
            baslangicAfter:
                a == null ? null : DateTime(a.start.year, a.start.month, a.start.day),
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        forbidden: false,
        items: page.items,
        ozet: page.ozet,
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
    }
  }
}

final patrolHistoryControllerProvider =
    NotifierProvider<PatrolHistoryController, PatrolHistoryState>(
  PatrolHistoryController.new,
);
