import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/kargo_api.dart';
import '../domain/kargo_models.dart';

/// Kargo listesinin durumu.
class KargoState {
  const KargoState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.canRegister = false,
    this.canReceive = false,
    this.refreshedAt,
  });

  final bool loading;

  /// Hata KANALI ikilidir (README §15): [errorMessage] SUNUCU metnini,
  /// [hataKimligi] yerellestirilebilir kimligi tasir (denetleyicide
  /// `BuildContext` yok).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: created_at DESC (en yeni onde). Sakin icin sunucu zaten
  /// YALNIZ kendi dairesinin paketlerini doner.
  final List<Kargo> items;

  /// Rol security mi — "Yeni kargo" FAB'i. Yalniz UX kapisi; gercek yetki
  /// backend RBAC'ta.
  final bool canRegister;

  /// Rol resident mi — bekleyen kartta "Teslim aldim" butonu (dairenin
  /// sakini olma kosulunu sunucu ayrica zorlar).
  final bool canReceive;

  final DateTime? refreshedAt;

  KargoState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<Kargo>? items,
    bool? canRegister,
    bool? canReceive,
    DateTime? refreshedAt,
  }) {
    return KargoState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      items: items ?? this.items,
      canRegister: canRegister ?? this.canRegister,
      canReceive: canReceive ?? this.canReceive,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Kargo listesi controller'i. Kayit/teslim eylemleri basarili olunca listeyi
/// tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException
/// yukari firlatilir — orn. ikinci teslim isareti 409'u).
class KargoController extends Notifier<KargoState> {
  bool _refreshing = false;

  @override
  KargoState build() {
    Future.microtask(refresh);
    return const KargoState(loading: true);
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
      final role = await ref.read(currentUserRoleProvider.future);
      final items = await ref.read(kargoApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
        canRegister: role.canRegisterKargo,
        canReceive: role.canReceiveKargo,
        refreshedAt: DateTime.now(),
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

  Future<void> register(KargoDraft draft) async {
    await ref.read(kargoApiProvider).create(draft);
    await refresh();
  }

  Future<void> markReceived(String id) async {
    try {
      await ref.read(kargoApiProvider).markReceived(id);
    } finally {
      // 409 (es zaten teslim aldi) durumunda da guncel durumu cek —
      // kartta dogru sonuc gorunsun; hata yine cagirana firlar.
      await refresh();
    }
  }
}

final kargoControllerProvider = NotifierProvider<KargoController, KargoState>(
  KargoController.new,
);
