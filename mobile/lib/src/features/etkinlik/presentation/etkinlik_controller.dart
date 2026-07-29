import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/etkinlik_api.dart';
import '../domain/etkinlik_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// Etkinlik listesinin durumu.
class EtkinlikState {
  const EtkinlikState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.canManage = false,
    this.canRsvp = false,
    this.refreshedAt,
  });

  final bool loading;

  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: etkinlik tarihi DESC. Sayilar SEFFAF (herkes gorur);
  /// benimDurumum kullanicinin kendi beyani.
  final List<Etkinlik> items;

  /// Rol admin/yonetici mi — olustur/duzenle/sil. Yalniz UX kapisi; gercek
  /// yetki backend RBAC'ta.
  final bool canManage;

  /// Rol resident mi — Katiliyorum/Katilmiyorum beyani.
  final bool canRsvp;

  final DateTime? refreshedAt;

  EtkinlikState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<Etkinlik>? items,
    bool? canManage,
    bool? canRsvp,
    DateTime? refreshedAt,
  }) {
    return EtkinlikState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      items: items ?? this.items,
      canManage: canManage ?? this.canManage,
      canRsvp: canRsvp ?? this.canRsvp,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Etkinlik controller'i. Olustur/duzenle/sil/RSVP basarili olunca listeyi
/// tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException
/// yukari firlatilir).
class EtkinlikController extends Notifier<EtkinlikState> {
  bool _refreshing = false;

  @override
  EtkinlikState build() {
    Future.microtask(refresh);
    return const EtkinlikState(loading: true);
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
      final items = await ref.read(etkinlikApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        canManage: role.canManageEvents,
        canRsvp: role.canRsvpEvents,
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

  Future<void> create(EtkinlikDraft draft) async {
    await ref.read(etkinlikApiProvider).create(draft);
    await refresh();
  }

  Future<void> update(String id, EtkinlikDraft draft) async {
    await ref.read(etkinlikApiProvider).update(id, draft);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(etkinlikApiProvider).delete(id);
    await refresh();
  }

  Future<void> rsvp(String id, KatilimDurum durum) async {
    try {
      await ref.read(etkinlikApiProvider).rsvp(id, durum);
    } finally {
      // Basarida sayac guncellenir; hatada da guncel durum cekilir
      // (hata yine cagirana firlar, mesaj ekranda gosterilir).
      await refresh();
    }
  }
}

final etkinlikControllerProvider =
    NotifierProvider<EtkinlikController, EtkinlikState>(EtkinlikController.new);
