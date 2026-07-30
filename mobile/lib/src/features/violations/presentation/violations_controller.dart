import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/violation_api.dart';
import '../domain/violation_models.dart';

/// Ihlal listesinin durumu (ziyaretci/talep modullerindeki desen).
class ViolationsState {
  const ViolationsState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.suzgec,
    this.canManage = false,
    this.canClose = false,
    this.erisimYok = false,
  });

  final bool loading;
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: created_at DESC.
  final List<Ihlal> items;

  /// null = tumu.
  final IhlalDurum? suzgec;

  /// Kayit acma + durum ilerletme (admin + security).
  final bool canManage;

  /// KAPATMA yetkisi — yalniz admin (dort-goz kurali).
  final bool canClose;

  /// 403 — rol bu listeyi goremiyor (resident / tesis_gorevlisi).
  final bool erisimYok;

  ViolationsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<Ihlal>? items,
    Object? suzgec = _sentinel,
    bool? canManage,
    bool? canClose,
    bool? erisimYok,
  }) => ViolationsState(
    loading: loading ?? this.loading,
    errorMessage: errorMessage == _sentinel
        ? this.errorMessage
        : errorMessage as String?,
    hataKimligi: hataKimligi == _sentinel
        ? this.hataKimligi
        : hataKimligi as AkisHatasi?,
    items: items ?? this.items,
    suzgec: suzgec == _sentinel ? this.suzgec : suzgec as IhlalDurum?,
    canManage: canManage ?? this.canManage,
    canClose: canClose ?? this.canClose,
    erisimYok: erisimYok ?? this.erisimYok,
  );

  static const Object _sentinel = Object();
}

class ViolationsController extends Notifier<ViolationsState> {
  bool _refreshing = false;

  @override
  ViolationsState build() {
    Future.microtask(refresh);
    return const ViolationsState(loading: true);
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
          .read(violationApiProvider)
          .fetchAll(durum: state.suzgec);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
        canManage: role.canManageViolations,
        canClose: role.canCloseViolations,
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

  Future<void> suzgecDegistir(IhlalDurum? d) async {
    if (d == state.suzgec) return;
    state = state.copyWith(suzgec: d);
    await refresh();
  }

  Future<void> ac(IhlalDraft draft) async {
    await ref.read(violationApiProvider).create(draft);
    await refresh();
  }

  /// Hata EYLEMI cagiran ekranda gosterilir (ApiException yukari firlar):
  /// 403 (kapatma yetkisi yok) ve 409 (kapali kayit) kullaniciya AYRI
  /// mesajlarla anlatilir.
  Future<void> durumDegistir(String id, IhlalDurum durum) async {
    await ref.read(violationApiProvider).durumDegistir(id, durum);
    await refresh();
  }
}

final violationsControllerProvider =
    NotifierProvider<ViolationsController, ViolationsState>(
      ViolationsController.new,
    );
