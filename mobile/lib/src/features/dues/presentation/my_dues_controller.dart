import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../data/dues_api.dart';
import '../domain/dues_models.dart';

/// "Aidatim" ekraninin durumu.
class MyDuesState {
  const MyDuesState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.forbidden = false,
    this.units = const [],
    this.refreshedAt,
  });

  final bool loading;
  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final bool forbidden;
  final List<MyDuesUnit> units;
  final DateTime? refreshedAt;

  /// Tum dairelerin toplam borcu (goruntuleme; birim toplamlari sunucudan).
  int get toplamBakiyeKurus =>
      units.fold(0, (sum, u) => sum + u.bakiyeKurus);

  MyDuesState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    bool? forbidden,
    List<MyDuesUnit>? units,
    DateTime? refreshedAt,
  }) {
    return MyDuesState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      forbidden: forbidden ?? this.forbidden,
      units: units ?? this.units,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

class MyDuesController extends Notifier<MyDuesState> {
  bool _refreshing = false;

  @override
  MyDuesState build() {
    Future.microtask(refresh);
    return const MyDuesState(loading: true);
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
      final units = await ref.read(duesApiProvider).fetchMyDues();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        forbidden: false,
        units: units,
        refreshedAt: DateTime.now(),
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
      _refreshing = false;
    }
  }
}

final myDuesControllerProvider =
    NotifierProvider<MyDuesController, MyDuesState>(MyDuesController.new);
