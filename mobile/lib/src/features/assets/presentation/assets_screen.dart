import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/asset_models.dart';
import 'assets_controller.dart';

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demirbaş'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Etiket okut'),
              Tab(text: 'Üzerimdekiler${myCount > 0 ? ' ($myCount)' : ''}'),
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
    final busy = state.scanPhase == AssetScanPhase.reading ||
        state.scanPhase == AssetScanPhase.resolving;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.scanned == null) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Demirbaşı alırken veya bırakırken üzerindeki NFC etiketini '
                'okutun. Uygulama demirbaşı tanır ve kimde olduğunu gösterir.',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (state.scanError != null)
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.scanError!,
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
            onPressed: busy ? null : controller.scanTag,
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
                AssetScanPhase.reading => 'Etiket bekleniyor...',
                AssetScanPhase.resolving => 'Demirbaş tanınıyor...',
                _ =>
                  state.scanned == null ? 'Etiket okut' : 'Başka etiket okut',
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
    final (icon, color, durumText) = switch (info.verdict) {
      ZimmetVerdict.kimsedeDegil => (
          Icons.lock_open,
          Colors.green,
          'Kimsede değil — alınabilir.',
        ),
      ZimmetVerdict.sende => (
          Icons.person,
          Colors.blue,
          'SENDE — '
              '${_sinceText(info.acikZimmet?.alinmaZamani)} üzerinde.',
        ),
      ZimmetVerdict.baskasinda => (
          Icons.person_outline,
          Colors.orange,
          info.acikZimmet == null
              ? 'Başkasının üzerinde görünüyor.'
              : 'Başkasında: ${_holderName(info.acikZimmet!)} — '
                  '${_sinceText(info.acikZimmet!.alinmaZamani)} üzerinde.',
        ),
      ZimmetVerdict.bakimda => (
          Icons.build_circle_outlined,
          Colors.grey,
          'Bakımda — şu an zimmetlenemez.',
        ),
    };

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
                'Zorla devralma yok — demirbaşı şu anki kullanıcısı '
                'bırakmalı.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.actionMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.actionMessage!,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (state.actionError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.actionError!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            if (info.verdict == ZimmetVerdict.kimsedeDegil)
              FilledButton.icon(
                onPressed:
                    state.actionBusy ? null : controller.checkoutScanned,
                icon: _actionIcon(state.actionBusy, Icons.download),
                label: const Text('Zimmetine al'),
              )
            else if (info.verdict == ZimmetVerdict.sende)
              FilledButton.icon(
                onPressed:
                    state.actionBusy ? null : controller.checkinScanned,
                icon: _actionIcon(state.actionBusy, Icons.upload),
                label: const Text('Bırak / iade et'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son hareketler',
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
                            ? '${_userLabel(co)} aldı — '
                                '${_fmtDateTime(co.almaZamani.toLocal())} '
                                '(hala üzerinde)'
                            : '${_userLabel(co)} · '
                                '${_fmtDateTime(co.almaZamani.toLocal())} → '
                                '${_fmtDateTime(co.birakmaZamani!.toLocal())}',
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
                      ? 'Demirbaş listesi için yetkiniz yok.'
                      : state.myError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (state.myItems.isEmpty && state.myError == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Şu an üzerinde demirbaş görünmüyor.',
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
                  'Aldın: ${_fmtDateTime(item.zimmet.alinmaZamani.toLocal())} '
                  '(${_sinceText(item.zimmet.alinmaZamani)})',
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
                        child: const Text('Bırak'),
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

String _sinceText(DateTime? since) {
  if (since == null) return 'bir süredir';
  final d = DateTime.now().toUtc().difference(since.toUtc());
  if (d.inMinutes < 1) return 'az önce alındı, o zamandan beri';
  if (d.inMinutes < 60) return '${d.inMinutes} dakikadır';
  if (d.inHours < 24) return '${d.inHours} saattir';
  return '${d.inDays} gündür';
}

String _two(int v) => v.toString().padLeft(2, '0');

String _fmtDateTime(DateTime local) =>
    '${_two(local.day)}.${_two(local.month)} '
    '${_two(local.hour)}:${_two(local.minute)}';
