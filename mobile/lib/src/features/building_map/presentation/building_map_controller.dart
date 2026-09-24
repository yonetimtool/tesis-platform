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
    this.kategori,
  });

  final bool loading;

  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final BuildingMap? map;

  /// (E2E 2026-09) TESIS-17: secili sikayet turu (`wire`); null = tumu.
  final String? kategori;

  BuildingMapState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    BuildingMap? map,
    Object? kategori = _sentinel,
  }) {
    return BuildingMapState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      map: map ?? this.map,
      kategori: kategori == _sentinel ? this.kategori : kategori as String?,
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
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      hataKimligi: null,
    );
    try {
      final map = await ref
          .read(buildingMapApiProvider)
          .fetchMap(kategori: state.kategori);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        map: map,
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

  /// (E2E 2026-09) TESIS-17: tur secicisi — haritayi o ture gore yeniden
  /// okur. Suren bir yenileme varsa bitince secim yine uygulanir.
  Future<void> setKategori(String? kategori) async {
    if (kategori == state.kategori) return;
    state = state.copyWith(kategori: kategori);
    while (_refreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!ref.mounted) return;
    }
    await refresh();
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
