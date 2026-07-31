import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../../checkpoints/data/checkpoint_api.dart';
import '../../scan/data/konum_servisi.dart';
import '../../scan/data/scan_outbox.dart';
import '../../scan/domain/okutma_hata_kodu.dart';
import '../../scan/domain/outbox_entry.dart';
import '../../scan/domain/scan.dart';
import '../../tasks/data/task_api.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../domain/nfc_hatasi.dart';
import '../domain/nfc_read_result.dart';
import 'nfc_hata_metni.dart';
import 'nfc_controller.dart';

/// "Etiketi okutun" ekrani. Etiket okununca okutma ANINDA kalici outbox'a
/// yazilir (offline'da kaybolmaz); baglanti varsa arka planda hemen gonderilir
/// ve sonuc (yeni / zaten kayitli / eslesmedi) burada gosterilir.
class NfcScreen extends ConsumerStatefulWidget {
  const NfcScreen({super.key});

  @override
  ConsumerState<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends ConsumerState<NfcScreen> {
  /// Bu ekranda son okutulan kaydin outbox anahtari — durum kutusu bunu izler.
  String? _currentKey;

  /// Fotograf kapisi icin yukleme suruyor mu (buton kilitlenir).
  bool _fotoYukleniyor = false;

  /// Son okutmanin konum sonucu — kullaniciya BOSLUK GOSTERILIR.
  /// Sessizce konumsuz gondermek, gorevlinin konum izninin kapali oldugunu
  /// hic ogrenmemesi demekti.
  KonumSonucu? _sonKonum;

  Future<void> _startNewRead() async {
    setState(() => _currentKey = null);
    await ref
        .read(nfcControllerProvider.notifier)
        .startReading(nfcIosMetinleri(context.l10n));
    if (!mounted) return;

    final result = ref.read(nfcControllerProvider).result;
    if (result == null || !result.isSuccess || result.uid == null) return;

    // Okuma aninda taslak uret: okutma zamani + idempotency-key SABITLENIR.
    // NTAG424 SDM alanlari (varsa) taslaga eklenir; NTAG21x'te null kalir ve
    // govdeye hic girmez — mevcut akis degismez.
    // KONUM OKUTMA ANINDA olculur, gonderim aninda degil: kuyrukta bekleyen
    // bir kayit saatler sonra BASKA BIR YERDE gonderilebilir ve o konum
    // okutmanin konumu OLMAZDI.
    final konum = await _konumAl();
    if (!mounted) return;

    final sdm = result.sdmData;
    final draft = ScanDraft(
      nfcTagUid: result.uid!,
      okutmaZamani: result.readAt ?? DateTime.now().toUtc(),
      gpsLat: konum.lat,
      gpsLng: konum.lng,
      konumDurumu: konumDurumuKodu[konum.durum],
      gpsDogrulukM: konum.dogrulukM,
      sdmPiccData: sdm?.piccData,
      sdmCmac: sdm?.cmac,
    );
    setState(() => _currentKey = draft.idempotencyKey);
    await ref.read(scanOutboxProvider.notifier).enqueue(draft);
  }

  /// TEST (yalniz debug): fiziksel etiket olmadan bir kontrol noktasini secip
  /// okutmayi simule eder — ayni akis (outbox -> POST /scans) calisir. Release
  /// derlemesinde GORUNMEZ (NFC "fiziksel varlik" kaniti korunur).
  Future<void> _manualTestScan() async {
    final messenger = ScaffoldMessenger.of(context);
    List<Checkpoint> checkpoints;
    try {
      checkpoints = await ref.read(checkpointsProvider.future);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.nfcNoktalarAlinamadi('$e'))),
      );
      return;
    }
    final aktif = checkpoints.where((c) => c.aktif).toList();
    if (!mounted) return;
    final secilen = await showModalBottomSheet<Checkpoint>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(_l10n.nfcTestBaslik,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_l10n.nfcTestAlt),
            ),
            if (aktif.isEmpty)
              ListTile(
                title: Text(_l10n.nfcAktifNoktaYok),
                subtitle: Text(_l10n.nfcAktifNoktaYokAlt),
              )
            else
              for (final c in aktif)
                ListTile(
                  leading: const Icon(Icons.nfc),
                  title: Text(c.ad),
                  subtitle: Text(_l10n.nfcUidSatir(ltrIzole(c.nfcTagUid))),
                  onTap: () => Navigator.of(context).pop(c),
                ),
          ],
        ),
      ),
    );
    if (secilen == null) return;
    final konum = await _konumAl();
    if (!mounted) return;
    final draft = ScanDraft(
      nfcTagUid: secilen.nfcTagUid,
      okutmaZamani: DateTime.now().toUtc(),
      gpsLat: konum.lat,
      gpsLng: konum.lng,
      konumDurumu: konumDurumuKodu[konum.durum],
      gpsDogrulukM: konum.dogrulukM,
    );
    setState(() => _currentKey = draft.idempotencyKey);
    await ref.read(scanOutboxProvider.notifier).enqueue(draft);
  }

  /// Konumu alir; SONUC NE OLURSA OLSUN okutma devam eder.
  Future<KonumSonucu> _konumAl() async {
    final sonuc = await ref.read(konumKaynagiProvider).al(
          zamanAsimi: const Duration(seconds: 6),
        );
    if (mounted) setState(() => _sonKonum = sonuc);
    return sonuc;
  }

  /// (P34) Fotograf kapisi: KAMERA ONLY — galeriden secim YOK.
  ///
  /// Galeriye izin vermek, kanit degerini sifirlardi: eski bir fotografi
  /// secmek tura hic cikmadan tur baslatmak olurdu. Kamera yolu ise fotografi
  /// O AN uretir; sunucu da zaman ve konumu ayrica kaydeder.
  Future<void> _fotografCekVeGonder(OutboxEntry entry) async {
    if (_fotoYukleniyor) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fotoYukleniyor = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: ImageSource.camera,
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (file == null || !mounted) return;
      final api = ref.read(taskApiProvider);
      const contentType = 'image/jpeg';
      final ticket = await api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      await api.uploadPhoto(
        ticket: ticket,
        bytes: await file.readAsBytes(),
        contentType: contentType,
      );
      if (!mounted) return;
      await ref
          .read(scanOutboxProvider.notifier)
          .fotografEkle(entry.idempotencyKey, ticket.fotoKey);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.nfcFotoYuklenemedi('$e'))),
      );
    } finally {
      if (mounted) setState(() => _fotoYukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcControllerProvider);
    final nfc = ref.read(nfcControllerProvider.notifier);
    final l10n = context.l10n;
    final outboxState = ref.watch(scanOutboxProvider);
    final currentEntry =
        _currentKey == null ? null : outboxState.byKey(_currentKey!);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.nfcBaslik, context.dilKodu)),
        actions: [
          _OutboxBadge(
            pendingCount: outboxState.pendingCount,
            onTap: () => context.push(AppRoutes.outbox),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusIcon(status: state.status),
              const SizedBox(height: 16),
              Text(
                _statusLabel(l10n, state.status),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (state.status == NfcStatus.success && state.result != null) ...[
                _ResultCard(result: state.result!),
                const SizedBox(height: 16),
                _OutboxOutcome(entry: currentEntry),
                if (_sonKonum != null && !_sonKonum!.konumVar)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _konumUyarisi(l10n, _sonKonum!.durum),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (currentEntry?.hataKodu == okutmaFotoGerekliKod) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _fotoYukleniyor
                        ? null
                        : () => _fotografCekVeGonder(currentEntry!),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_fotoYukleniyor
                        ? l10n.nfcFotoYukleniyor
                        : l10n.nfcFotoCek),
                  ),
                ],
              ],
              if (state.status == NfcStatus.error)
                _ErrorBox(
                  message: nfcHataMetni(
                    l10n,
                    state.hata ?? NfcHatasi.bilinmeyen,
                    detay: state.hataDetay,
                  ),
                ),
              const SizedBox(height: 32),
              _ActionButton(
                status: state.status,
                onRead: _startNewRead,
                onCancel: () => nfc.cancel(iptalMetni: l10n.nfcIosIptal),
              ),
              // TEST (yalniz debug): fiziksel etiket olmadan okutma simulasyonu.
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.status == NfcStatus.reading
                      ? null
                      : _manualTestScan,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.nfcManuelOkut),
                ),
                Text(
                  l10n.nfcTestGorunur,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  String _konumUyarisi(AppLocalizations l10n, KonumDurumu durum) =>
      switch (durum) {
        KonumDurumu.izinYok => l10n.nfcKonumIzinYok,
        KonumDurumu.servisKapali => l10n.nfcKonumServisKapali,
        _ => l10n.nfcKonumYok,
      };

  String _statusLabel(AppLocalizations l10n, NfcStatus status) {
    return switch (status) {
      NfcStatus.ready => l10n.nfcHazir,
      NfcStatus.reading => l10n.nfcYaklastirBekliyor,
      NfcStatus.success => l10n.nfcOkundu,
      NfcStatus.error => l10n.gorevEtiketOkunamadi,
    };
  }
}

/// AppBar'daki bekleyen-kayit rozeti ("3 bekliyor" → kuyruk ekrani).
class _OutboxBadge extends StatelessWidget {
  const _OutboxBadge({required this.pendingCount, required this.onTap});

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: pendingCount > 0
          ? l10n.nfcKuyrukBekleyen(pendingCount)
          : l10n.nfcKuyruk,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: pendingCount > 0,
        label: Text('$pendingCount'),
        child: const Icon(Icons.outbox_outlined),
      ),
    );
  }
}

/// Okutmanin outbox'taki durumunu kullaniciya anlasilir yansitir:
/// kaydedildi (gonderilecek) / gonderiliyor / gonderildi / eslesmedi.
class _OutboxOutcome extends StatelessWidget {
  const _OutboxOutcome({required this.entry});

  final OutboxEntry? entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();
    final l10n = context.l10n;

    return switch (e.status) {
      OutboxStatus.bekliyor => _ScanOutcome(
          icon: Icons.check_circle,
          color: Colors.teal,
          text: l10n.nfcKaydedildiBekliyor,
        ),
      OutboxStatus.gonderiliyor => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              // Dar ekranda satira sigmayabilir — sar.
              Expanded(child: Text(l10n.nfcKaydedildiGonderiliyor)),
            ],
          ),
        ),
      OutboxStatus.gonderildi => e.outcome == OutboxOutcome.duplicate
          ? _ScanOutcome(
              icon: Icons.info_outline,
              color: Colors.blueGrey,
              text: l10n.nfcGonderildiZatenVar,
            )
          : _ScanOutcome(
              icon: Icons.check_circle,
              color: Colors.green,
              text: l10n.nfcGonderildi,
            ),
      // `lastError` SUNUCU metnidir (tur 14'ten beri istegin dilinde;
      // tur 14 oncesi kuyruga yazilmis eski kayitlar Turkce kalir).
      // (P34) Fotograf kapisi KALICI BIR HATA DEGIL: yapilacak sey bellidir
      // ve ekran altta kamera butonunu gosterir — "eslesmedi" ikonuyla
      // gostermek kullaniciya kaydin kaybedildigini dusundururdu.
      OutboxStatus.kaliciHata => e.hataKodu == okutmaFotoGerekliKod
          ? _ScanOutcome(
              icon: Icons.photo_camera_outlined,
              color: Colors.orange,
              text: l10n.nfcFotoGerekli,
            )
          : _ScanOutcome(
              icon: Icons.link_off,
              color: Colors.orange,
              text: e.lastError ?? l10n.nfcEslesmeYok,
            ),
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final NfcStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == NfcStatus.reading) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: CircularProgressIndicator(strokeWidth: 5),
      );
    }
    final (icon, color) = switch (status) {
      NfcStatus.ready => (Icons.nfc, Colors.blueGrey),
      NfcStatus.success => (Icons.check_circle_outline, Colors.green),
      NfcStatus.error => (Icons.error_outline, Colors.red),
      NfcStatus.reading => (Icons.nfc, Colors.blueGrey),
    };
    return Icon(icon, size: 64, color: color);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final NfcReadResult result;

  @override
  Widget build(BuildContext context) {
    final sdm = result.sdmData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 'UID' teknik alan adidir (cevrilmez); 'Tip' cevrilir.
            _KvRow(label: 'UID', value: result.uid ?? '-'),
            const SizedBox(height: 8),
            _KvRow(label: context.l10n.nfcTipEtiket, value: result.tagType.name),
            if (sdm != null) ...[
              const Divider(height: 24),
              Text(
                context.l10n.nfcSdmBaslik,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _KvRow(label: 'PICCData', value: sdm.piccData ?? '-'),
              _KvRow(label: 'CMAC', value: sdm.cmac ?? '-'),
              _KvRow(label: 'URL', value: sdm.rawUrl),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanOutcome extends StatelessWidget {
  const _ScanOutcome({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.onRead,
    required this.onCancel,
  });

  final NfcStatus status;
  final VoidCallback onRead;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (status) {
      case NfcStatus.reading:
        return OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: Text(l10n.ortakVazgec),
        );
      case NfcStatus.ready:
        return FilledButton.icon(
          onPressed: onRead,
          icon: const Icon(Icons.nfc),
          label: Text(l10n.nfcOkumayaBasla),
        );
      case NfcStatus.success:
      case NfcStatus.error:
        return OutlinedButton.icon(
          onPressed: onRead,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.nfcTekrarOku),
        );
    }
  }
}
