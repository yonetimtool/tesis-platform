import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../nfc/presentation/nfc_hata_metni.dart';
import '../domain/asset_models.dart';
import 'assets_controller.dart';
import 'demirbas_mesaj_metni.dart';

/// "Demirbas" — NFC-oncelikli zimmet ekrani.
///
///   * Okut sekmesi: buyuk "Etiket okut" → UID → asset → duruma gore kart:
///     kimsede degil ("Zimmetine al") / sende ("Birak / iade et") /
///     baskasinda (bilgi — zorla alma YOK) / bakimda (bilgi). Kayitsiz
///     etiket net mesaj. Son hareketler kartta gosterilir.
///   * Uzerimdekiler sekmesi: su an bende olan demirbaslar (alinma
///     zamaniyla) + hizli "Birak".
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCount =
        ref.watch(assetsControllerProvider.select((s) => s.myItems.length));
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.demBaslik, context.dilKodu)),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.demEtiketOkut),
              Tab(
                text: l10n.demUzerimdekiler(
                  myCount > 0 ? ' ($myCount)' : '',
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ScanTab(),
            _MyItemsTab(),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// OKUT SEKMESI
// --------------------------------------------------------------------------

class _ScanTab extends ConsumerWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assetsControllerProvider);
    final controller = ref.read(assetsControllerProvider.notifier);
    final l10n = context.l10n;
    final busy = state.scanPhase == AssetScanPhase.reading ||
        state.scanPhase == AssetScanPhase.resolving;
    final scanHatasi = demirbasMesajCoz(l10n, state.scanError);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.scanned == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.demNfcAciklama),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (scanHatasi != null)
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                scanHatasi,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        if (state.scanned != null) ...[
          _ScannedCard(state: state, controller: controller),
          const SizedBox(height: 12),
          if (state.scanned!.recentHistory.isNotEmpty)
            _HistoryCard(info: state.scanned!),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed:
                busy ? null : () => controller.scanTag(nfcIosMetinleri(l10n)),
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.nfc),
            label: Text(
              switch (state.scanPhase) {
                AssetScanPhase.reading => l10n.gorevEtiketBekleniyor,
                AssetScanPhase.resolving => l10n.demTaniniyor,
                _ => state.scanned == null
                    ? l10n.demEtiketOkut
                    : l10n.demBaskaEtiketOkut,
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Okutulan demirbasin durum karti — durum makinesine gore ikon/renk/aksiyon.
class _ScannedCard extends StatelessWidget {
  const _ScannedCard({required this.state, required this.controller});

  final AssetsState state;
  final AssetsController controller;

  @override
  Widget build(BuildContext context) {
    final info = state.scanned!;
    final l10n = context.l10n;
    final (icon, color, durumText) = switch (info.verdict) {
      ZimmetVerdict.kimsedeDegil => (
          Icons.lock_open,
          Colors.green,
          l10n.demKimsedeDegil,
        ),
      ZimmetVerdict.sende => (
          Icons.person,
          Colors.blue,
          l10n.demSende(_sinceText(l10n, info.acikZimmet?.alinmaZamani)),
        ),
      ZimmetVerdict.baskasinda => (
          Icons.person_outline,
          Colors.orange,
          info.acikZimmet == null
              ? l10n.demBaskasininUzerinde
              : l10n.demBaskasinda(
                  _holderName(info.acikZimmet!),
                  _sinceText(l10n, info.acikZimmet!.alinmaZamani),
                ),
        ),
      ZimmetVerdict.bakimda => (
          Icons.build_circle_outlined,
          Colors.grey,
          l10n.demBakimda,
        ),
    };
    final islemMesaji = demirbasMesajCoz(l10n, state.actionMessage);
    final islemHatasi = demirbasMesajCoz(l10n, state.actionError);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.asset.ad,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (info.asset.aciklama != null)
                        Text(
                          info.asset.aciklama!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              durumText,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (info.verdict == ZimmetVerdict.baskasinda) ...[
              const SizedBox(height: 4),
              Text(
                l10n.demZorlaDevralmaYok,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (islemMesaji != null) ...[
              const SizedBox(height: 8),
              Text(
                islemMesaji,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (islemHatasi != null) ...[
              const SizedBox(height: 8),
              Text(
                islemHatasi,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            if (info.verdict == ZimmetVerdict.kimsedeDegil)
              FilledButton.icon(
                onPressed:
                    state.actionBusy ? null : controller.checkoutScanned,
                icon: _actionIcon(state.actionBusy, Icons.download),
                label: Text(l10n.demZimmetineAl),
              )
            else if (info.verdict == ZimmetVerdict.sende)
              FilledButton.icon(
                onPressed:
                    state.actionBusy ? null : controller.checkinScanned,
                icon: _actionIcon(state.actionBusy, Icons.upload),
                label: Text(l10n.demBirak),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(bool busy, IconData icon) => busy
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);
}

/// Son hareketler (en yeni once): kim aldi/birakti, ne zaman.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.info});

  final ScannedAssetInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.demSonHareketler,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final co in info.recentHistory.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      co.isOpen ? Icons.download : Icons.upload,
                      size: 16,
                      color: co.isOpen ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        co.isOpen
                            ? l10n.demAldi(
                                _userLabel(co),
                                _kisaZaman(co.almaZamani, dil),
                              )
                            : l10n.demAldiBirakti(
                                _userLabel(co),
                                _kisaZaman(co.almaZamani, dil),
                                _kisaZaman(co.birakmaZamani!, dil),
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// UZERIMDEKILER SEKMESI
// --------------------------------------------------------------------------

class _MyItemsTab extends ConsumerWidget {
  const _MyItemsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assetsControllerProvider);
    final controller = ref.read(assetsControllerProvider.notifier);
    final l10n = context.l10n;
    final dil = context.dilKodu;

    if (state.myLoading && state.myItems.isEmpty && state.myError == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refreshMyItems,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.myError != null)
            Card(
              color: Colors.red.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.forbidden
                      ? l10n.demListeYetkiYok
                      : demirbasMesajMetni(l10n, state.myError!),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (state.myItems.isEmpty && state.myError == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.demUzerindeYok,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final item in state.myItems)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.asset.ad),
                subtitle: Text(
                  l10n.demAldin(
                    _kisaZaman(item.zimmet.alinmaZamani, dil),
                    _sinceText(l10n, item.zimmet.alinmaZamani),
                  ),
                ),
                trailing: state.quickCheckinBusyId == item.asset.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: state.quickCheckinBusyId != null
                            ? null
                            : () => controller.quickCheckin(item),
                        child: Text(l10n.demBirakKisa),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// ORTAK
// --------------------------------------------------------------------------

/// Kullanici adi artik sunucudan gelir (§13 #5 kapandi); ad bos gelirse
/// (eski kayit) kisa id'ye duselim.
String _holderName(AcikZimmet z) =>
    z.alanUserAd.trim().isNotEmpty ? z.alanUserAd : _shortId(z.alanUserId);

String _userLabel(AssetCheckout co) =>
    (co.alanUserAd != null && co.alanUserAd!.trim().isNotEmpty)
        ? co.alanUserAd!
        : _shortId(co.alanUserId);

String _shortId(String userId) =>
    userId.length > 8 ? '${userId.substring(0, 8)}…' : userId;

/// "Ne zamandan beri" PARCASI — cumleye `{sure}` olarak girer. EDAT parcanin
/// kendisindedir (bkz. `@demSende` notu): sablon yalniz yerlestirir, boylece
/// hicbir dilde edat iki kez yazilmaz.
String _sinceText(AppLocalizations l10n, DateTime? since) {
  if (since == null) return l10n.demSureBelirsiz;
  final d = DateTime.now().toUtc().difference(since.toUtc());
  if (d.inMinutes < 1) return l10n.demSureAzOnce;
  if (d.inMinutes < 60) return l10n.demSureDakika(d.inMinutes);
  if (d.inHours < 24) return l10n.demSureSaat(d.inHours);
  return l10n.demSureGun(d.inDays);
}

/// GUN.AY SAAT — hareket satirlarinin kisa zamani (yil yok; kayitlar guncel).
String _kisaZaman(DateTime t, String dil) =>
    '${gunAyBicimi(t, dil)} ${saatBicimi(t, dil)}';
