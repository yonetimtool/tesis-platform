import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/patrol_api.dart';
import '../domain/patrol_models.dart';

/// "Gecmis" sekmesinin durumu: son pencereler + ozet sayilar.
class PatrolHistoryState {
  const PatrolHistoryState({
    this.loading = false,
    this.errorMessage,
    this.forbidden = false,
    this.items = const [],
    this.ozet = const PatrolWindowOzet(),
  });

  final bool loading;
  final String? errorMessage;
  final bool forbidden;
  final List<PatrolWindowHistoryItem> items;
  final PatrolWindowOzet ozet;

  PatrolHistoryState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    bool? forbidden,
    List<PatrolWindowHistoryItem>? items,
    PatrolWindowOzet? ozet,
  }) {
    return PatrolHistoryState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      forbidden: forbidden ?? this.forbidden,
      items: items ?? this.items,
      ozet: ozet ?? this.ozet,
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

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final page = await ref
          .read(patrolApiProvider)
          .fetchWindowHistory(limit: _pageSize);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        items: page.items,
        ozet: page.ozet,
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
    }
  }
}

final patrolHistoryControllerProvider =
    NotifierProvider<PatrolHistoryController, PatrolHistoryState>(
  PatrolHistoryController.new,
);
