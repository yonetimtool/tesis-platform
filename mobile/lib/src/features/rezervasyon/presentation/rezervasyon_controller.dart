import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart'
    show currentUserRoleProvider, currentUserIdProvider;
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
    this.currentUserId,
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

  /// Rol resident mi — rezerve eder + KENDI rezervasyonunu iptal edebilir.
  final bool canRequest;

  /// Oturumdaki kullanicinin id'si — sakin YALNIZ KENDI rezervasyonunu iptal
  /// eder (talep_eden == kendisi).
  final String? currentUserId;

  final DateTime? refreshedAt;

  /// Bu rezervasyon icin iptal butonu gosterilsin mi. Kurallar (backend zorlar,
  /// bu istemci kapisi UX aynasi): (1) aktif (onayli), (2) YALNIZ rezerve eden
  /// sakinin kendisi (yonetim iptal ETMEZ), (3) slot baslangicina >=10 dk kala.
  bool canCancel(Rezervasyon r) {
    if (!r.onayli) return false;
    if (!canRequest || r.talepEdenUserId != currentUserId) return false;
    final start = _slotStart(r);
    if (start == null) return true; // parse edilemedi -> backend karar verir
    return start.difference(DateTime.now()) >= const Duration(minutes: 10);
  }

  /// Rezervasyonun slot baslangicini yerel DateTime'a cevirir (tarih + saat).
  /// tenant yerel saati cihaz yerel saati kabul edilir (backend nihai otorite).
  static DateTime? _slotStart(Rezervasyon r) {
    final g = r.tarih.split('-');
    final s = r.baslangic.split(':');
    if (g.length != 3 || s.length < 2) return null;
    final y = int.tryParse(g[0]);
    final mo = int.tryParse(g[1]);
    final d = int.tryParse(g[2]);
    final h = int.tryParse(s[0]);
    final mi = int.tryParse(s[1]);
    if (y == null || mo == null || d == null || h == null || mi == null) {
      return null;
    }
    return DateTime(y, mo, d, h, mi);
  }

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
    Object? currentUserId = _sentinel,
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
      currentUserId: currentUserId == _sentinel
          ? this.currentUserId
          : currentUserId as String?,
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
      final userId = await ref.read(currentUserIdProvider.future);
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
        currentUserId: userId,
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

  /// Alanin secili gunune ait slot izgarasi (dolu/bos) — talep formu kullanir.
  Future<List<Slot>> slots(String alanId, String date) =>
      ref.read(rezervasyonApiProvider).fetchSlots(alanId, date);

  Future<void> cancel(String id) async {
    try {
      await ref.read(rezervasyonApiProvider).cancel(id);
    } finally {
      // 409 (zaten iptal) durumunda da guncel durumu cek; hata yine cagirana
      // firlar (mesaj ekranda gosterilir).
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
