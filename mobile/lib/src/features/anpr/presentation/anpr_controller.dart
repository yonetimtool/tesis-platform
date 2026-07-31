import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/anpr_api.dart';
import '../domain/anpr_models.dart';

/// Plaka olaylari ekraninin durumu (arac gecisi ekraniyla ayni desen).
class AnprState {
  const AnprState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.suzgec,
    this.canDecide = false,
    this.erisimYok = false,
  });

  final bool loading;
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: created_at DESC.
  final List<AnprOlay> items;

  /// null = tumu.
  final AnprDurum? suzgec;

  /// Onay verebilir mi (admin + security; okuma ile ayni kume).
  final bool canDecide;

  /// 403 — rol bu defteri goremiyor (plaka kisisel veriye baglanabilir).
  final bool erisimYok;

  /// Kuyrukta kac okuma insan karari bekliyor (rozet).
  int get bekleyenSayisi => items.where((o) => o.onayBekliyor).length;

  AnprState copyWith({
    bool? loading,
    Object? errorMessage = _s,
    Object? hataKimligi = _s,
    List<AnprOlay>? items,
    Object? suzgec = _s,
    bool? canDecide,
    bool? erisimYok,
  }) => AnprState(
    loading: loading ?? this.loading,
    errorMessage: errorMessage == _s
        ? this.errorMessage
        : errorMessage as String?,
    hataKimligi: hataKimligi == _s
        ? this.hataKimligi
        : hataKimligi as AkisHatasi?,
    items: items ?? this.items,
    suzgec: suzgec == _s ? this.suzgec : suzgec as AnprDurum?,
    canDecide: canDecide ?? this.canDecide,
    erisimYok: erisimYok ?? this.erisimYok,
  );

  static const Object _s = Object();
}

class AnprController extends Notifier<AnprState> {
  bool _refreshing = false;

  @override
  AnprState build() {
    Future.microtask(refresh);
    return const AnprState(loading: true);
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
      final items = await ref
          .read(anprApiProvider)
          .fetchAll(durum: state.suzgec);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
        canDecide: role.canViewVehiclePasses,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
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

  Future<void> suzgecDegistir(AnprDurum? d) async {
    if (d == state.suzgec) return;
    state = state.copyWith(suzgec: d);
    await refresh();
  }

  /// Hata EYLEMI cagiran ekranda gosterilir (409 = olay onay beklemiyor).
  Future<void> karar(String id, {required bool onay, String? plaka}) async {
    await ref.read(anprApiProvider).onayla(id, onay: onay, plaka: plaka);
    await refresh();
  }
}

final anprControllerProvider = NotifierProvider<AnprController, AnprState>(
  AnprController.new,
);
