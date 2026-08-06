import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../data/unit_complaint_api.dart';
import '../domain/unit_complaint_models.dart';

/// "Şikayetlerim" durumu — sakinin KENDI actigi daire sikayetleri (gitti mi
/// geri bildirimi). Yogunluk/renk/complainant YOK.
class MyComplaintsState {
  const MyComplaintsState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
  });

  final bool loading;

  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final List<UnitComplaint> items;

  MyComplaintsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<UnitComplaint>? items,
  }) {
    return MyComplaintsState(
      loading: loading ?? this.loading,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      items: items ?? this.items,
    );
  }

  static const Object _sentinel = Object();
}

class MyComplaintsController extends Notifier<MyComplaintsState> {
  bool _refreshing = false;

  @override
  MyComplaintsState build() {
    Future.microtask(refresh);
    return const MyComplaintsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      hataKimligi: null,
    );
    try {
      final items = await ref.read(unitComplaintApiProvider).fetchMine();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        hataKimligi: e.agHatasi,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    } finally {
      _refreshing = false;
    }
  }

  /// (P146) Sikayeti GERI AL — sahibinin eylemi. Sunucu yalniz `acik`
  /// sikayette kabul eder; hata cagirana YUKSELIR (sessizce yutulmaz).
  Future<void> withdraw(String id) async {
    await ref.read(unitComplaintApiProvider).withdraw(id);
    await refresh();
  }

}

final myComplaintsControllerProvider =
    NotifierProvider<MyComplaintsController, MyComplaintsState>(
  MyComplaintsController.new,
);
