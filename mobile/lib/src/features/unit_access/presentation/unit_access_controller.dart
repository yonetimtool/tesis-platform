import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/unit_access_api.dart';
import '../domain/unit_access_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// Tek-seferlik daire erisim izni listesinin durumu (rol-uyarlamali).
class UnitAccessState {
  const UnitAccessState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.grantedUnits = const [],
    this.canRequest = false,
    this.canDecide = false,
    this.refreshedAt,
  });

  final bool loading;
  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final List<UnitAccessRequest> items;

  /// Talep edenin (admin/yonetici) SU AN goruntuleyebilecegi daireler
  /// (onayli + kullanilmamis) — bulk sonrasi "hangi daireler acildi" gorunumu.
  final List<GrantedUnit> grantedUnits;

  /// admin/yonetici — "Yeni istek" (talep acma) + "Tüm dairelere izin iste".
  final bool canRequest;

  /// resident — gelen talebi Onayla/Reddet.
  final bool canDecide;

  final DateTime? refreshedAt;

  /// Bekleyenler one alinir (karar bekleyen gomulmesin).
  List<UnitAccessRequest> get sirali => [
        ...items.where((r) => r.bekliyor),
        ...items.where((r) => !r.bekliyor),
      ];

  UnitAccessState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<UnitAccessRequest>? items,
    List<GrantedUnit>? grantedUnits,
    bool? canRequest,
    bool? canDecide,
    DateTime? refreshedAt,
  }) {
    return UnitAccessState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      items: items ?? this.items,
      grantedUnits: grantedUnits ?? this.grantedUnits,
      canRequest: canRequest ?? this.canRequest,
      canDecide: canDecide ?? this.canDecide,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

class UnitAccessController extends Notifier<UnitAccessState> {
  bool _refreshing = false;

  @override
  UnitAccessState build() {
    Future.microtask(refresh);
    return const UnitAccessState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final api = ref.read(unitAccessApiProvider);
      final items = await api.fetchAll();
      // Talep eden (admin/yonetici) icin "acilan daireler" gorunumu; sakin
      // icin bos (o uca 403 — cagirmayiz). Hata olursa liste yine gosterilir.
      var granted = const <GrantedUnit>[];
      if (role.canRequestUnitAccess) {
        try {
          granted = await api.fetchGrantedUnits();
        } on ApiException {
          granted = const [];
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        grantedUnits: granted,
        canRequest: role.canRequestUnitAccess,
        canDecide: role.canDecideUnitAccess,
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

  /// Talep ac (admin/yonetici) — basari/hata cagirana firlatilir (form gosterir).
  Future<void> createRequest(String unitNo) async {
    await ref.read(unitAccessApiProvider).createRequest(unitNo);
    await refresh();
  }

  /// Toplu talep (admin/yonetici): TUM sakinli daireler icin bekleyen talep.
  /// Sonuc (created/skipped) cagirana doner (SnackBar gosterir); liste tazelenir.
  Future<BulkAccessRequestResult> createBulkRequest() async {
    final res = await ref.read(unitAccessApiProvider).createBulkRequest();
    await refresh();
    return res;
  }

  Future<void> decide(String id, {required bool onayla}) async {
    try {
      await ref.read(unitAccessApiProvider).decide(id, onayla: onayla);
    } finally {
      await refresh();
    }
  }
}

final unitAccessControllerProvider =
    NotifierProvider<UnitAccessController, UnitAccessState>(
  UnitAccessController.new,
);
