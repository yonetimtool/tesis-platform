import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../../nfc/presentation/nfc_controller.dart';
import '../data/asset_api.dart';
import '../domain/asset_models.dart';

/// Okutma akisinin asamasi.
enum AssetScanPhase { idle, reading, resolving, done }

/// Okutulan etiketin cozumlenmis sonucu: demirbas + acik zimmet + karar.
class ScannedAssetInfo {
  const ScannedAssetInfo({
    required this.asset,
    required this.verdict,
    required this.scannedUid,
    this.recentHistory = const [],
  });

  final Asset asset;
  final ZimmetVerdict verdict;

  /// Okutulan ham UID (checkout/checkin govdesine gider).
  final String scannedUid;

  /// Acik zimmet ozeti dogrudan sunucu yanitindan (history taramasi yok).
  AcikZimmet? get acikZimmet => asset.acikZimmet;

  /// Son hareketler (sunucu varsayilani DESC — en yeni once).
  final List<AssetCheckout> recentHistory;
}

/// "Uzerimdekiler" satiri: demirbas + acik zimmet ozeti (alinma zamani icin).
typedef MyAssetItem = ({Asset asset, AcikZimmet zimmet});

class AssetsState {
  const AssetsState({
    this.scanPhase = AssetScanPhase.idle,
    this.scanned,
    this.scanError,
    this.actionBusy = false,
    this.actionError,
    this.actionMessage,
    this.myItems = const [],
    this.myLoading = false,
    this.myError,
    this.forbidden = false,
    this.quickCheckinBusyId,
    this.currentUserId,
  });

  final AssetScanPhase scanPhase;
  final ScannedAssetInfo? scanned;
  final String? scanError;

  /// Okutma kartindaki al/birak islemi suruyor.
  final bool actionBusy;
  final String? actionError;

  /// Basarili islem mesaji ("Zimmetine alindi ✓" vb.).
  final String? actionMessage;

  /// Su an bende olan demirbaslar (istemcide suzulur — sunucu filtresi yok).
  final List<MyAssetItem> myItems;
  final bool myLoading;
  final String? myError;

  /// 403 — rol asset uclarina erisemiyor.
  final bool forbidden;

  /// "Uzerimdekiler" listesindeki hizli birakma isleminin asset id'si.
  final String? quickCheckinBusyId;

  final String? currentUserId;

  AssetsState copyWith({
    AssetScanPhase? scanPhase,
    Object? scanned = _sentinel,
    Object? scanError = _sentinel,
    bool? actionBusy,
    Object? actionError = _sentinel,
    Object? actionMessage = _sentinel,
    List<MyAssetItem>? myItems,
    bool? myLoading,
    Object? myError = _sentinel,
    bool? forbidden,
    Object? quickCheckinBusyId = _sentinel,
    Object? currentUserId = _sentinel,
  }) {
    return AssetsState(
      scanPhase: scanPhase ?? this.scanPhase,
      scanned:
          scanned == _sentinel ? this.scanned : scanned as ScannedAssetInfo?,
      scanError:
          scanError == _sentinel ? this.scanError : scanError as String?,
      actionBusy: actionBusy ?? this.actionBusy,
      actionError:
          actionError == _sentinel ? this.actionError : actionError as String?,
      actionMessage: actionMessage == _sentinel
          ? this.actionMessage
          : actionMessage as String?,
      myItems: myItems ?? this.myItems,
      myLoading: myLoading ?? this.myLoading,
      myError: myError == _sentinel ? this.myError : myError as String?,
      forbidden: forbidden ?? this.forbidden,
      quickCheckinBusyId: quickCheckinBusyId == _sentinel
          ? this.quickCheckinBusyId
          : quickCheckinBusyId as String?,
      currentUserId: currentUserId == _sentinel
          ? this.currentUserId
          : currentUserId as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Demirbas zimmet controller'i.
///
///   * NFC-oncelikli akis: mevcut [NfcService] ile etiket okunur →
///     `GET /assets?nfc_tag_uid=` TEK istekle asset + acik zimmet ozeti →
///     duruma gore karar ([zimmetVerdict]): kimsede degil / sende /
///     baskasinda / bakimda.
///   * Checkout/checkin: Idempotency-Key aksiyon ANINDA sabitlenir;
///     409 yarisi (sen okurken baskasi aldi) kibarca gosterilir ve kart
///     taze durumla yeniden cizilir.
///   * OFFLINE KARARI: zimmet CANLI durum isidir — baglanti yokken islem
///     YAPILMAZ (kuyruklamak yaniltici + yaris riski); net uyari verilir.
class AssetsController extends Notifier<AssetsState> {
  bool _refreshingMy = false;

  @override
  AssetsState build() {
    Future.microtask(refreshMyItems);
    return const AssetsState(myLoading: true);
  }

  AssetApi get _api => ref.read(assetApiProvider);

  static const _offlineMessage =
      'İnternet bağlantısı gerekli. Zimmet kimde-olduğu ANLIK bir kayıttır; '
      'offline işlem yapılmaz (kuyruklamak yanıltıcı olurdu).';

  /// Buyuk "Etiket okut" akisi: NFC oku → asset'i coz → durumu getir.
  Future<void> scanTag() async {
    if (state.scanPhase == AssetScanPhase.reading ||
        state.scanPhase == AssetScanPhase.resolving) {
      return;
    }
    state = state.copyWith(
      scanPhase: AssetScanPhase.reading,
      scanned: null,
      scanError: null,
      actionError: null,
      actionMessage: null,
    );

    final result = await ref.read(nfcServiceProvider).readSingleTag();
    if (!ref.mounted) return;
    if (!result.isSuccess) {
      state = state.copyWith(
        scanPhase: AssetScanPhase.idle,
        scanError: result.error ?? 'Etiket okunamadı.',
      );
      return;
    }

    state = state.copyWith(scanPhase: AssetScanPhase.resolving);
    try {
      // UID → asset: tek istek (§13 #1 kapandi); yanit acik_zimmet tasir.
      final match = await _api.findByUid(result.uid!);
      if (!ref.mounted) return;
      if (match == null) {
        state = state.copyWith(
          scanPhase: AssetScanPhase.idle,
          scanError: 'Bu etiket (${result.uid}) kayıtlı bir demirbaşla '
              'eşleşmiyor. Etiket panelden bir demirbaşa tanımlanmalı.',
        );
        return;
      }
      await _showScanned(match, result.uid!);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        scanPhase: AssetScanPhase.idle,
        scanError:
            e.kind == ApiErrorKind.network ? _offlineMessage : e.message,
        forbidden: e.statusCode == 403,
      );
    }
  }

  /// Aksiyon sonrasi tazeleme: taze detay (acik_zimmet dahil) + son
  /// hareketler — kart her zaman SUNUCU gercegiyle cizilir.
  Future<void> _resolveAndShow(String assetId, String scannedUid) async {
    final asset = await _api.fetchAsset(assetId);
    await _showScanned(asset, scannedUid);
  }

  /// Eldeki (taze) asset yanitiyla sonucu kurar; yalnizca son hareketler
  /// icin ek bir history istegi atilir (DESC → dogrudan ilk sayfa).
  Future<void> _showScanned(Asset asset, String scannedUid) async {
    final recent = await _api.fetchRecentHistory(asset.id);
    final myUserId = await ref.read(currentUserIdProvider.future);
    if (!ref.mounted) return;
    state = state.copyWith(
      scanPhase: AssetScanPhase.done,
      scanned: ScannedAssetInfo(
        asset: asset,
        scannedUid: scannedUid,
        recentHistory: recent,
        verdict: zimmetVerdict(
          asset: asset,
          acikZimmet: asset.acikZimmet,
          myUserId: myUserId,
        ),
      ),
      currentUserId: myUserId,
      scanError: null,
    );
  }

  /// Okutulan demirbasi zimmetine al. Idempotency-Key BASIS aninda sabit.
  Future<void> checkoutScanned() => _performAction(AssetActionTip.alma);

  /// Okutulan demirbasi birak.
  Future<void> checkinScanned() => _performAction(AssetActionTip.birakma);

  Future<void> _performAction(AssetActionTip tip) async {
    final scanned = state.scanned;
    if (scanned == null || state.actionBusy) return;
    state = state.copyWith(
      actionBusy: true,
      actionError: null,
      actionMessage: null,
    );

    final draft = tip == AssetActionTip.alma
        ? AssetActionDraft.checkout(
            assetId: scanned.asset.id,
            islemAni: DateTime.now().toUtc(),
            nfcTagUid: scanned.scannedUid,
          )
        : AssetActionDraft.checkin(
            assetId: scanned.asset.id,
            islemAni: DateTime.now().toUtc(),
            nfcTagUid: scanned.scannedUid,
          );

    try {
      final result = tip == AssetActionTip.alma
          ? await _api.checkout(draft)
          : await _api.checkin(draft);
      if (!ref.mounted) return;
      state = state.copyWith(
        actionMessage: tip == AssetActionTip.alma
            ? (result.wasDuplicate
                ? 'Zaten zimmetindeydi ✓ (tekrar gönderim — çift kayıt yok)'
                : 'Zimmetine alındı ✓')
            : 'Bırakıldı ✓ — zimmet kapatıldı.',
      );
      await _resolveAndShow(scanned.asset.id, scanned.scannedUid);
      await refreshMyItems(silent: true);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      final offline = e.kind == ApiErrorKind.network;
      // 409: yaris (baskasi aldi / coktan birakildi) — kibarca soyle ve
      // karti taze durumla yeniden ciz.
      state = state.copyWith(
        actionError: offline
            ? _offlineMessage
            : e.statusCode == 409
                ? 'İşlem yapılamadı: ${e.message} Durum güncellendi — '
                    'karta tekrar bakın.'
                : e.message,
      );
      if (!offline && e.statusCode == 409) {
        try {
          await _resolveAndShow(scanned.asset.id, scanned.scannedUid);
        } on ApiException {
          // Kart eski haliyle kalir; kullanici yeniden okutabilir.
        }
      }
    } finally {
      if (ref.mounted) state = state.copyWith(actionBusy: false);
    }
  }

  /// "Uzerimdekiler": `GET /assets?checked_out_by=me` TEK istek
  /// (§13 #3 kapandi — N+1 history suzmesi kaldirildi).
  Future<void> refreshMyItems({bool silent = false}) async {
    if (_refreshingMy) return;
    _refreshingMy = true;
    if (!silent) {
      state = state.copyWith(myLoading: true, myError: null);
    }
    try {
      final myUserId = await ref.read(currentUserIdProvider.future);
      final mine = await _api.fetchMyAssets();
      if (!ref.mounted) return;

      final items = <MyAssetItem>[
        for (final a in mine)
          if (a.acikZimmet != null) (asset: a, zimmet: a.acikZimmet!),
      ];
      items.sort(
        (a, b) => b.zimmet.alinmaZamani.compareTo(a.zimmet.alinmaZamani),
      );
      state = state.copyWith(
        myItems: items,
        myLoading: false,
        myError: null,
        forbidden: false,
        currentUserId: myUserId,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        myLoading: false,
        myError:
            e.kind == ApiErrorKind.network ? _offlineMessage : e.message,
        forbidden: e.statusCode == 403,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        myLoading: false,
        myError: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshingMy = false;
    }
  }

  /// "Uzerimdekiler" satirindan hizli birakma.
  Future<void> quickCheckin(MyAssetItem item) async {
    if (state.quickCheckinBusyId != null) return;
    state = state.copyWith(quickCheckinBusyId: item.asset.id, myError: null);
    final draft = AssetActionDraft.checkin(
      assetId: item.asset.id,
      islemAni: DateTime.now().toUtc(),
      // Listeden birakmada etiket okutulmaz; UID gonderilmez (sozlesmede
      // opsiyonel — dogrulama yalnizca verilirse yapilir).
    );
    try {
      await _api.checkin(draft);
      if (!ref.mounted) return;
      await refreshMyItems(silent: true);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        myError: e.kind == ApiErrorKind.network
            ? _offlineMessage
            : e.statusCode == 409
                ? '${item.asset.ad}: ${e.message}'
                : e.message,
      );
      await refreshMyItems(silent: true);
    } finally {
      if (ref.mounted) state = state.copyWith(quickCheckinBusyId: null);
    }
  }

  /// Okutma kartini kapat, yeni okutmaya hazirlan.
  void clearScan() {
    state = state.copyWith(
      scanPhase: AssetScanPhase.idle,
      scanned: null,
      scanError: null,
      actionError: null,
      actionMessage: null,
    );
  }
}

final assetsControllerProvider =
    NotifierProvider<AssetsController, AssetsState>(AssetsController.new);
