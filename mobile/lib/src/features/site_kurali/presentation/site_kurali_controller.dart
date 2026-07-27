import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/site_kurali_api.dart';
import '../domain/site_kurali_models.dart';

/// Site kurallari ekraninin durumu.
class SiteKuraliState {
  const SiteKuraliState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.items = const [],
    this.sorgu = '',
    this.canManage = false,
    this.refreshedAt,
  });

  final bool loading;
  /// Hata KANALI ikilidir (README §15): [errorMessage] SUNUCU metnini,
  /// [hataKimligi] yerellestirilebilir kimligi tasir (denetleyicide
  /// `BuildContext` yok).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Sunucu sirasi: sira ASC (esitlikte eski once) — blog listesi.
  final List<SiteKurali> items;

  /// Arama cubugu metni — suzme ISTEMCIDE anlik yapilir (tam liste zaten
  /// cekili; sunucuda ?q= ILIKE ayrica mevcut — sozlesme/testli).
  final String sorgu;

  /// Rol admin/yonetici mi — ekle/duzenle/sil. Yalniz UX kapisi; gercek
  /// yetki backend RBAC'ta.
  final bool canManage;

  final DateTime? refreshedAt;

  /// Arama suzgecinden gecen kurallar (sorgu bossa tum liste).
  List<SiteKurali> get suzulmus => sorgu.trim().isEmpty
      ? items
      : items
          .where((k) => k.baslikEslesir(sorgu.trim()))
          .toList(growable: false);

  SiteKuraliState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<SiteKurali>? items,
    String? sorgu,
    bool? canManage,
    DateTime? refreshedAt,
  }) {
    return SiteKuraliState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      items: items ?? this.items,
      sorgu: sorgu ?? this.sorgu,
      canManage: canManage ?? this.canManage,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Site kurallari controller'i. Ekle/duzenle/sil basarili olunca listeyi
/// tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir (ApiException
/// yukari firlatilir).
class SiteKuraliController extends Notifier<SiteKuraliState> {
  bool _refreshing = false;

  @override
  SiteKuraliState build() {
    Future.microtask(refresh);
    return const SiteKuraliState(loading: true);
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
      final items = await ref.read(siteKuraliApiProvider).fetchAll();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        items: items,
        canManage: role.canManageSiteRules,
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

  /// Arama cubugu — istemci tarafi ANLIK suzgec (ag cagrisi yok).
  void search(String sorgu) {
    state = state.copyWith(sorgu: sorgu);
  }

  Future<void> create(SiteKuraliDraft draft) async {
    await ref.read(siteKuraliApiProvider).create(draft);
    await refresh();
  }

  Future<void> update(String id, SiteKuraliDraft draft) async {
    await ref.read(siteKuraliApiProvider).update(id, draft);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(siteKuraliApiProvider).delete(id);
    await refresh();
  }
}

final siteKuraliControllerProvider =
    NotifierProvider<SiteKuraliController, SiteKuraliState>(
  SiteKuraliController.new,
);
