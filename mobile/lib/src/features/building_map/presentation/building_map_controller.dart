import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/building_map_api.dart';
import '../domain/building_map_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// Bina semasi ekrani durumu — harita (blok->kat->daire + renk) yuklenir;
/// yonetici bir dairenin yerlesimini (blok/kat/sira) gunceller.
class BuildingMapState {
  const BuildingMapState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.map,
  });

  final bool loading;
  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final BuildingMap? map;

  BuildingMapState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    BuildingMap? map,
  }) {
    return BuildingMapState(
      loading: loading ?? this.loading,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      map: map ?? this.map,
    );
  }

  static const Object _sentinel = Object();
}

class BuildingMapController extends Notifier<BuildingMapState> {
  bool _refreshing = false;

  @override
  BuildingMapState build() {
    Future.microtask(refresh);
    return const BuildingMapState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      final map = await ref.read(buildingMapApiProvider).fetchMap();
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: null, hataKimligi: null, map: map);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message, hataKimligi: null);
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

  /// Yerlesim guncelle (yonetim). Basari sonrasi haritayi yeniden okur ki
  /// gruplama/renk tazelensin. Hata -> ApiException (ekran mesaji gosterir).
  Future<void> updateLayout(String unitId, UnitLayoutDraft draft) async {
    await ref.read(buildingMapApiProvider).updateLayout(unitId, draft);
    await refresh();
  }
}

final buildingMapControllerProvider =
    NotifierProvider<BuildingMapController, BuildingMapState>(
  BuildingMapController.new,
);
