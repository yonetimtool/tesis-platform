import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/rezervasyon_api.dart';
import '../domain/rezervasyon_models.dart';

/// Rezervasyon ekraninin durumu (alanlar + rezervasyonlar birlikte).
class RezervasyonState {
  const RezervasyonState({
    this.loading = false,
    this.errorMessage,
    this.alanlar = const [],
    this.items = const [],
    this.canManageAreas = false,
    this.canRequest = false,
    this.canDecide = false,
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// Alanlar (ada gore): yonetim pasifleri de gorur, sakin yalniz aktifleri
  /// (sunucu daraltir).
  final List<OrtakAlan> alanlar;

  /// Sunucu sirasi: created_at DESC. Sakin icin sunucu zaten YALNIZ kendi
  /// dairesinin rezervasyonlarini doner.
  final List<Rezervasyon> items;

  /// Rol admin/yonetici mi — alan olustur/duzenle. Yalniz UX kapisi;
  /// gercek yetki backend RBAC'ta.
  final bool canManageAreas;

  /// Rol resident mi — "Yeni rezervasyon" talebi.
  final bool canRequest;

  /// Rol admin/yonetici mi — bekleyen kartta Onayla/Reddet.
  final bool canDecide;

  final DateTime? refreshedAt;

  /// Sakinin secebilecegi (aktif) alanlar.
  List<OrtakAlan> get aktifAlanlar =>
      alanlar.where((a) => a.aktif).toList(growable: false);

  RezervasyonState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<OrtakAlan>? alanlar,
    List<Rezervasyon>? items,
    bool? canManageAreas,
    bool? canRequest,
    bool? canDecide,
    DateTime? refreshedAt,
  }) {
    return RezervasyonState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      alanlar: alanlar ?? this.alanlar,
      items: items ?? this.items,
      canManageAreas: canManageAreas ?? this.canManageAreas,
      canRequest: canRequest ?? this.canRequest,
      canDecide: canDecide ?? this.canDecide,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Rezervasyon controller'i. Talep/karar/alan eylemleri basarili olunca
/// veriyi tazeler; hata mesaji EYLEMI cagiran ekranda gosterilir
/// (ApiException yukari firlatilir — orn. cakisma 409'u).
class RezervasyonController extends Notifier<RezervasyonState> {
  bool _refreshing = false;

  @override
  RezervasyonState build() {
    Future.microtask(refresh);
    return const RezervasyonState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final api = ref.read(rezervasyonApiProvider);
      final alanlar = await api.fetchAreas();
      // Saha rolleri /reservations goremez (403) — bu ekran zaten menude yok;
      // yine de savunmaci: rol izinliyse cek.
      final items = role.canViewReservations
          ? await api.fetchReservations()
          : <Rezervasyon>[];
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        alanlar: alanlar,
        items: items,
        canManageAreas: role.canManageCommonAreas,
        canRequest: role.canRequestReservation,
        canDecide: role.canDecideReservations,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> request(RezervasyonDraft draft) async {
    await ref.read(rezervasyonApiProvider).createReservation(draft);
    await refresh();
  }

  Future<void> decide(String id, {required bool onayla}) async {
    try {
      await ref.read(rezervasyonApiProvider).decide(id, onayla: onayla);
    } finally {
      // 409 (cakisma / zaten karara baglandi) durumunda da guncel durumu
      // cek; hata yine cagirana firlar (mesaj ekranda gosterilir).
      await refresh();
    }
  }

  Future<void> createArea(OrtakAlanDraft draft) async {
    await ref.read(rezervasyonApiProvider).createArea(draft);
    await refresh();
  }

  Future<void> setAreaActive(String id, bool aktif) async {
    await ref.read(rezervasyonApiProvider).updateArea(id, {'aktif': aktif});
    await refresh();
  }
}

final rezervasyonControllerProvider =
    NotifierProvider<RezervasyonController, RezervasyonState>(
  RezervasyonController.new,
);
