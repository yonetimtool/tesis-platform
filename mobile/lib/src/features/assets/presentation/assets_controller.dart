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
    this.openCheckout,
    this.recentHistory = const [],
  });

  final Asset asset;
  final ZimmetVerdict verdict;

  /// Okutulan ham UID (completion'a degil, checkout/checkin govdesine gider).
  final String scannedUid;

  final AssetCheckout? openCheckout;

  /// Son hareketler (EN YENI ONCE — gecmis karti icin).
  final List<AssetCheckout> recentHistory;
}

/// "Uzerimdekiler" satiri: demirbas + acik zimmet (alinma zamani icin).
typedef MyAssetItem = ({Asset asset, AssetCheckout checkout});

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
///   * NFC-oncelikli akis: mevcut [NfcService] ile etiket okunur → UID,
///     istemci indeksiyle asset'e cozulur (sunucuda UID aramasi yok) →
///     taze detay + acik zimmet cekilir → duruma gore karar
///     ([zimmetVerdict]): kimsede degil / sende / baskasinda / bakimda.
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
      'Internet baglantisi gerekli. Zimmet kimde-oldugu ANLIK bir kayittir; '
      'offline islem yapilmaz (kuyruklamak yaniltici olurdu).';

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
        scanError: result.error ?? 'Etiket okunamadi.',
      );
      return;
    }

    state = state.copyWith(scanPhase: AssetScanPhase.resolving);
    try {
      // UID → asset: sunucuda arama olmadigi icin aktif liste + indeks.
      // Envanter kucuk oldugu icin her okutmada taze cekilir (bayatlik yok).
      final index = buildUidIndex(await _api.fetchAssets());
      final match = lookupByUid(index, result.uid!);
      if (!ref.mounted) return;
      if (match == null) {
        state = state.copyWith(
          scanPhase: AssetScanPhase.idle,
          scanError: 'Bu etiket (${result.uid}) kayitli bir demirbasla '
              'eslesmiyor. Etiket panelden bir demirbasa tanimlanmali.',
        );
        return;
      }
      await _resolveAndShow(match.id, result.uid!);
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

  /// Taze detay + gecmis kuyrugu ile sonucu kurar (aksiyon sonrasi da
  /// cagrilir — kart her zaman SUNUCU gercegiyle cizilir).
  Future<void> _resolveAndShow(String assetId, String scannedUid) async {
    final asset = await _api.fetchAsset(assetId);
    final tail = await _api.fetchHistoryTail(assetId);
    final myUserId = await ref.read(currentUserIdProvider.future);
    if (!ref.mounted) return;
    final open = findOpenCheckout(tail);
    state = state.copyWith(
      scanPhase: AssetScanPhase.done,
      scanned: ScannedAssetInfo(
        asset: asset,
        scannedUid: scannedUid,
        openCheckout: open,
        recentHistory: tail.reversed.toList(),
        verdict: zimmetVerdict(
          asset: asset,
          openCheckout: open,
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
                ? 'Zaten zimmetindeydi ✓ (tekrar gonderim — cift kayit yok)'
                : 'Zimmetine alindi ✓')
            : 'Birakildi ✓ — zimmet kapatildi.',
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
                ? 'Islem yapilamadi: ${e.message} Durum guncellendi — '
                    'karta tekrar bakin.'
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

  /// "Uzerimdekiler": sunucuda `checked_out_by=me` filtresi YOK (sozlesme
  /// dogrulandi, README §13'te flag'li) → zimmetli asset'lerin acik
  /// zimmetleri taranir, benimkiler suzulur.
  Future<void> refreshMyItems({bool silent = false}) async {
    if (_refreshingMy) return;
    _refreshingMy = true;
    if (!silent) {
      state = state.copyWith(myLoading: true, myError: null);
    }
    try {
      final myUserId = await ref.read(currentUserIdProvider.future);
      final zimmetli = await _api.fetchAssets(durum: AssetDurum.zimmetli);
      final tails = await Future.wait(
        [for (final a in zimmetli) _api.fetchHistoryTail(a.id, lastN: 5)],
      );
      if (!ref.mounted) return;

      final items = <MyAssetItem>[];
      for (var i = 0; i < zimmetli.length; i++) {
        final open = findOpenCheckout(tails[i]);
        if (open != null && myUserId != null && open.alanUserId == myUserId) {
          items.add((asset: zimmetli[i], checkout: open));
        }
      }
      items.sort((a, b) => b.checkout.almaZamani.compareTo(
            a.checkout.almaZamani,
          ));
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
        myError: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
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
