import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/report_api.dart';
import '../domain/report_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// "Aylik raporlar" ekraninin durumu — secili ay + o ayin derlenen raporu.
class ReportsState {
  const ReportsState({
    required this.yil,
    required this.ay,
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.forbidden = false,
    this.rapor,
  });

  final int yil;
  final int ay;
  final bool loading;
  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final bool forbidden;
  final AylikRapor? rapor;

  ReportsState copyWith({
    int? yil,
    int? ay,
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    bool? forbidden,
    Object? rapor = _sentinel,
  }) {
    return ReportsState(
      yil: yil ?? this.yil,
      ay: ay ?? this.ay,
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      forbidden: forbidden ?? this.forbidden,
      rapor: rapor == _sentinel ? this.rapor : rapor as AylikRapor?,
    );
  }

  static const Object _sentinel = Object();
}

class ReportsController extends Notifier<ReportsState> {
  bool _loadingNow = false;

  @override
  ReportsState build() {
    final now = DateTime.now();
    Future.microtask(refresh);
    return ReportsState(yil: now.year, ay: now.month, loading: true);
  }

  Future<void> refresh() async {
    if (_loadingNow) return;
    _loadingNow = true;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      hataKimligi: null,
    );
    final (yil, ay) = (state.yil, state.ay);
    try {
      final rapor = await ref.read(reportApiProvider).fetchMonthly(yil, ay);
      if (!ref.mounted) return;
      // Kullanici bu arada ay degistirdiyse bayat sonucu yazma.
      if (state.yil != yil || state.ay != ay) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        forbidden: false,
        rapor: rapor,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        hataKimligi: null,
        forbidden: e.statusCode == 403,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    } finally {
      _loadingNow = false;
    }
  }

  /// Onceki aya gec.
  Future<void> prevMonth() => _setMonth(-1);

  /// Sonraki aya gec — icinde bulunulan aydan ileri gidilmez.
  Future<void> nextMonth() => _setMonth(1);

  bool get canGoNext {
    final now = DateTime.now();
    return state.yil < now.year ||
        (state.yil == now.year && state.ay < now.month);
  }

  Future<void> _setMonth(int delta) async {
    var yil = state.yil;
    var ay = state.ay + delta;
    if (ay < 1) {
      ay = 12;
      yil--;
    } else if (ay > 12) {
      ay = 1;
      yil++;
    }
    if (delta > 0 && !canGoNext) return;
    state = state.copyWith(yil: yil, ay: ay, rapor: null);
    await refresh();
  }
}

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);
