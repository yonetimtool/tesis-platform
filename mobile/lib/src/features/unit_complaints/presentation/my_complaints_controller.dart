import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/unit_complaint_api.dart';
import '../domain/unit_complaint_models.dart';

/// "Şikayetlerim" durumu — sakinin KENDI actigi daire sikayetleri (gitti mi
/// geri bildirimi). Yogunluk/renk/complainant YOK.
class MyComplaintsState {
  const MyComplaintsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
  });

  final bool loading;
  final String? errorMessage;
  final List<UnitComplaint> items;

  MyComplaintsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<UnitComplaint>? items,
  }) {
    return MyComplaintsState(
      loading: loading ?? this.loading,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
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
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final items = await ref.read(unitComplaintApiProvider).fetchMine();
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: null, items: items);
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
}

final myComplaintsControllerProvider =
    NotifierProvider<MyComplaintsController, MyComplaintsState>(
  MyComplaintsController.new,
);
