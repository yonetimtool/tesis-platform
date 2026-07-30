import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../../home/domain/parking_occupancy.dart';
import '../data/vehicle_pass_api.dart';
import '../domain/vehicle_pass_models.dart';

/// Arac gecisi listesinin durumu.
///
/// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
/// kimlik. Ekran once kimligi cozer, yoksa sunucu metnini gosterir.
class VehiclePassState {
  const VehiclePassState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.suzgec = GecisSuzgeci.tumu,
    this.sorgu = '',
    this.canManage = false,
    this.erisimYok = false,
    this.doluluk,
  });

  final bool loading;
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: giris_zamani DESC (en yeni onde).
  final List<VehiclePass> items;

  final GecisSuzgeci suzgec;

  /// Plaka ONEK aramasi — SUNUCUDA yapilir (normalize eslesme icin).
  final String sorgu;

  /// Giris kaydi + cikis damgasi yetkisi (UX kapisi; gercek yetki backend'de).
  final bool canManage;

  /// 403 — rol bu listeyi hic goremiyor. Hata bandi yerine ACIKLAYICI bos
  /// durum cizilir: "yetkin yok" bir ag hatasi degildir.
  final bool erisimYok;

  /// Ayni ekranin ust bandinda gosterilen agregat doluluk (ayri istek).
  final ParkingOccupancy? doluluk;

  VehiclePassState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<VehiclePass>? items,
    GecisSuzgeci? suzgec,
    String? sorgu,
    bool? canManage,
    bool? erisimYok,
    Object? doluluk = _sentinel,
  }) => VehiclePassState(
    loading: loading ?? this.loading,
    errorMessage: errorMessage == _sentinel
        ? this.errorMessage
        : errorMessage as String?,
    hataKimligi: hataKimligi == _sentinel
        ? this.hataKimligi
        : hataKimligi as AkisHatasi?,
    items: items ?? this.items,
    suzgec: suzgec ?? this.suzgec,
    sorgu: sorgu ?? this.sorgu,
    canManage: canManage ?? this.canManage,
    erisimYok: erisimYok ?? this.erisimYok,
    doluluk: doluluk == _sentinel ? this.doluluk : doluluk as ParkingOccupancy?,
  );

  static const Object _sentinel = Object();
}

class VehiclePassController extends Notifier<VehiclePassState> {
  bool _refreshing = false;

  @override
  VehiclePassState build() {
    Future.microtask(refresh);
    return const VehiclePassState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      hataKimligi: null,
      erisimYok: false,
    );
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final api = ref.read(vehiclePassApiProvider);
      final items = await api.fetchAll(
        suzgec: state.suzgec,
        plaka: state.sorgu,
      );
      // Doluluk AYRI uctur ve TUM rollere aciktir; listeyi cekebilen rol
      // dolulugu da cekebilir. Yine de basarisiz olursa liste yasar.
      ParkingOccupancy? doluluk;
      try {
        doluluk = await api.occupancy();
      } on ApiException {
        doluluk = null;
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
        canManage: role.canManageVehiclePasses,
        doluluk: doluluk,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      // 403 hata DEGIL, yetki durumudur — ayri cizilir.
      if (e.statusCode == 403) {
        state = state.copyWith(
          loading: false,
          items: const [],
          erisimYok: true,
          errorMessage: null,
          hataKimligi: null,
        );
        return;
      }
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

  Future<void> suzgecDegistir(GecisSuzgeci s) async {
    if (s == state.suzgec) return;
    state = state.copyWith(suzgec: s);
    await refresh();
  }

  /// Plaka aramasi SUNUCUDA yapilir: normalize eslesme ("34 abc" == "34ABC")
  /// yalniz sunucuda dogru calisir.
  Future<void> ara(String q) async {
    if (q == state.sorgu) return;
    state = state.copyWith(sorgu: q);
    await refresh();
  }

  Future<void> girisKaydet(VehiclePassDraft draft) async {
    await ref.read(vehiclePassApiProvider).create(draft);
    await refresh();
  }

  Future<void> cikisVer(String id) async {
    await ref.read(vehiclePassApiProvider).checkout(id);
    await refresh();
  }
}

final vehiclePassControllerProvider =
    NotifierProvider<VehiclePassController, VehiclePassState>(
      VehiclePassController.new,
    );

/// Otopark ekrani icin agregat doluluk — liste yetkisi GEREKTIRMEZ.
final otoparkDolulukProvider = FutureProvider.autoDispose<ParkingOccupancy>(
  (ref) => ref.watch(vehiclePassApiProvider).occupancy(),
);
