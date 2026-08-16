import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart'
    show currentUserRoleProvider, currentUserIdProvider;
import '../data/rezervasyon_api.dart';
import '../domain/rezervasyon_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// Rezervasyon ekraninin durumu (alanlar + rezervasyonlar birlikte).
class RezervasyonState {
  const RezervasyonState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.alanlar = const [],
    this.items = const [],
    this.gecmisItems = const [],
    this.gecmisYuklendi = false,
    this.gecmisLoading = false,
    this.canManageAreas = false,
    this.canRequest = false,
    this.currentUserId,
    this.refreshedAt,
  });

  final bool loading;
  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Alanlar (ada gore): yonetim pasifleri de gorur, sakin yalniz aktifleri
  /// (sunucu daraltir).
  final List<OrtakAlan> alanlar;

  /// AKTIF rezervasyonlar (suren + gelecek). Sunucu sirasi: created_at
  /// DESC. Sakin icin sunucu zaten YALNIZ kendi dairesinin
  /// rezervasyonlarini doner.
  final List<Rezervasyon> items;

  /// (P165) GECMIS rezervasyonlar — bitis saati gecmis olanlar.
  ///
  /// AYRI ISTEK, yerel suzgec DEGIL: `gecmis=true` sunucuda ayrica
  /// TESISIN SAKLAMA PENCERESINI uygular (`rezervasyon_gecmis_ay`).
  /// Tek listeyi istemcide bolmek, o pencereyi atlamak olurdu.
  final List<Rezervasyon> gecmisItems;

  /// Gecmis listesi BIR KEZ cekildi mi (TEMBEL YUKLEME).
  ///
  /// Her tazelemede iki istek atmak, gecmise hic bakmayan kullanicilarda da
  /// trafigi ikiye katlardi. Web de yalniz ACIK sekmeyi ceker (SWR anahtari
  /// sekmeye bagli) — davranis ayni.
  final bool gecmisYuklendi;

  /// Gecmis sekmesi kendi basina yukleniyor (ana `loading`den AYRI: aktif
  /// liste ekranda dururken gecmis yukleniyor olabilir).
  final bool gecmisLoading;

  /// Rol admin/yonetici mi — alan olustur/duzenle. Yalniz UX kapisi;
  /// gercek yetki backend RBAC'ta.
  final bool canManageAreas;

  /// Rol resident mi — rezerve eder + KENDI rezervasyonunu iptal edebilir.
  final bool canRequest;

  /// Oturumdaki kullanicinin id'si — sakin YALNIZ KENDI rezervasyonunu iptal
  /// eder (talep_eden == kendisi).
  final String? currentUserId;

  final DateTime? refreshedAt;

  /// Bu rezervasyon icin iptal butonu gosterilsin mi. Kurallar: (1) aktif
  /// (onayli), (2) YALNIZ rezerve eden sakinin kendisi (yonetim iptal ETMEZ).
  ///
  /// Zamanlama (slot baslangicina >=10 dk kala) kurali NIHAI olarak BACKEND'de
  /// zorlanir (gec kalinca 422 + mesaj). Istemci burada 10-dk on-kontrolu
  /// YAPMAZ: aksi halde slota yakin/gecmis kayitlarda buton sessizce gizlenir
  /// ("neden iptal edemiyorum?"). Buton kendi aktif rezervasyonunda hep gorunur.
  bool canCancel(Rezervasyon r) {
    // (P165 §3) GECMIS REZERVASYON IPTAL EDILEMEZ.
    //
    // Bildirilen kusur: saati gecmis kayitlarin altinda "Iptal et"
    // duruyordu. `r.gecmis` SUNUCUNUN hesapladigi bayrak — cihaz saatine
    // guvenilmez ve `tarih + bitis` ancak tesisin saat diliminde bir ANA
    // donusur.
    //
    // SEKMEYE BAKMAK YETMEZ: sayfa acikken bitis saati gecebilir; kosul
    // kaydin KENDI bayragi.
    if (r.gecmis) return false;
    if (!r.onayli) return false;
    return canRequest && r.talepEdenUserId == currentUserId;
  }

  /// Sakinin secebilecegi (aktif) alanlar.
  List<OrtakAlan> get aktifAlanlar =>
      alanlar.where((a) => a.aktif).toList(growable: false);

  RezervasyonState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<OrtakAlan>? alanlar,
    List<Rezervasyon>? items,
    List<Rezervasyon>? gecmisItems,
    bool? gecmisYuklendi,
    bool? gecmisLoading,
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
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      alanlar: alanlar ?? this.alanlar,
      items: items ?? this.items,
      gecmisItems: gecmisItems ?? this.gecmisItems,
      gecmisYuklendi: gecmisYuklendi ?? this.gecmisYuklendi,
      gecmisLoading: gecmisLoading ?? this.gecmisLoading,
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
  bool _gecmisYukleniyor = false;

  @override
  RezervasyonState build() {
    Future.microtask(refresh);
    return const RezervasyonState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      final api = ref.read(rezervasyonApiProvider);
      final alanlar = await api.fetchAreas();
      // Saha rolleri /reservations goremez (403) — bu ekran zaten menude yok;
      // yine de savunmaci: rol izinliyse cek.
      // (P165) AKTIF LISTE `gecmis=false` ILE CEKILIR — istemci suzgeci
      // DEGIL. Ayrim sunucuda ve TESISIN saat diliminde yapilir; cihaz
      // saati yanlis kurulu olabilir.
      final items = role.canViewReservations
          ? await api.fetchReservations(gecmis: false)
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
    // GECMIS ZATEN ACILDIYSA O DA TAZELENIR. Acilmadiysa istek atilmaz —
    // tembel yuklemenin butun amaci bu.
    if (state.gecmisYuklendi) await gecmisTazele(zorla: true);
  }

  /// (P165 §3) GECMIS LISTESI — SEKME ACILINCA cekilir.
  ///
  /// [zorla] false ise bir kez cekildikten sonra tekrar istek atmaz
  /// (sekmeler arasi gidip gelmek trafige donusmez).
  ///
  /// AYRI ISTEK, YEREL SUZGEC DEGIL: `gecmis=true` sunucuda ayrica TESISIN
  /// SAKLAMA PENCERESINI uygular (`rezervasyon_gecmis_ay`, goc 0054). Tek
  /// listeyi istemcide bolmek o pencereyi atlamak olurdu.
  Future<void> gecmisTazele({bool zorla = false}) async {
    if (_gecmisYukleniyor) return;
    if (state.gecmisYuklendi && !zorla) return;
    _gecmisYukleniyor = true;
    state = state.copyWith(gecmisLoading: true);
    try {
      final role = await ref.read(currentUserRoleProvider.future);
      final liste = role.canViewReservations
          ? await ref.read(rezervasyonApiProvider).fetchReservations(gecmis: true)
          : <Rezervasyon>[];
      if (!ref.mounted) return;
      state = state.copyWith(
        gecmisItems: liste,
        gecmisYuklendi: true,
        gecmisLoading: false,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      // HATA ANA KANALDAN gosterilir; `gecmisYuklendi` FALSE kalir ki
      // kullanici sekmeye donunce yeniden denensin.
      state = state.copyWith(
        gecmisLoading: false,
        errorMessage: e.message,
        hataKimligi: e.agHatasi,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        gecmisLoading: false,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    } finally {
      _gecmisYukleniyor = false;
    }
  }

  Future<void> request(RezervasyonDraft draft) async {
    // YARIS (tur 64): iki kullanici ayni slotu isteyince ikincisi 409 alir.
    // Onceki surum hatayi firlatip cikiyordu ve TAZELEME YAPMIYORDU; yani
    // yarisi kaybeden kullanici slotun artik dolu oldugunu GORMUYORDU (izgara
    // eski haliyle kaliyor, tekrar deniyor). `cancel` bunu `finally` ile
    // cozuyordu; `request` cozmuyordu — tutarsizlik olcumle ortaya cikti.
    try {
      await ref.read(rezervasyonApiProvider).createReservation(draft);
    } finally {
      // Hata halinde de guncel durum cekilir; hata YINE cagirana firlar
      // (mesaj ekranda gosterilir).
      await refresh();
    }
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

  /// Mevcut alani duzenle (ad/aciklama/musaitlik) — yalniz yonetim. Aktiflik
  /// icin ayri [setAreaActive] kullanilir (anahtar); bu PATCH aktifligi
  /// degistirmez (draft.aktif=null → govdeye yazilmaz).
  Future<void> editArea(String id, OrtakAlanDraft draft) async {
    await ref.read(rezervasyonApiProvider).updateArea(id, draft.toJson());
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
