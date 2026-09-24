import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../data/davet_yonetim_api.dart';

/// (E2E 2026-09, MOBIL-10) DAVETLER — web `/davetler` sayfasinin ikizi.
///
/// Yonetici kime davet gittigini / gitmedigini gorur ve kayit olmamis
/// kisiye yeniden gonderir. Durum etiketleri web ile AYNI (gonderildi /
/// iletildi / acildi / geri dondu / e-posta ayari yok / kaydoldu).
///
/// SAGLAYICI YOKKEN: tesis kodu kopyalanip elle iletilir (web ile ayni
/// yedek yol).
class DavetlerScreen extends ConsumerStatefulWidget {
  const DavetlerScreen({super.key});

  @override
  ConsumerState<DavetlerScreen> createState() => _DavetlerScreenState();
}

class _DavetlerScreenState extends ConsumerState<DavetlerScreen> {
  /// Gonderimi suren satirlar — ayni dugmeye iki kez basilmasin.
  final Set<String> _gonderiliyor = {};

  Future<void> _yenidenGonder(DavetSatiri d) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _gonderiliyor.add(d.userId));
    try {
      await ref.read(davetYonetimApiProvider).yenidenGonder(d.userId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.davetYonYenidenGonderildi)),
      );
      ref.invalidate(davetListesiProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _gonderiliyor.remove(d.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(davetListesiProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulDavetler, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(davetListesiProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(davetListesiProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              BosDurum(
                ikon: Icons.error_outline,
                baslik: l10n.davetYonAlinamadi,
                aciklama: e is ApiException ? apiHataMetni(l10n, e) : null,
              ),
            ],
          ),
          data: (liste) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                l10n.davetYonAciklama,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if ((liste.tesisKodu ?? '').isNotEmpty)
                _TesisKoduKarti(kod: liste.tesisKodu!),
              const SizedBox(height: 8),
              if (liste.items.isEmpty)
                BosDurum(
                  ikon: Icons.mark_email_unread_outlined,
                  baslik: l10n.davetYonBos,
                  aciklama: l10n.davetYonAciklama,
                )
              else
                for (final d in liste.items)
                  _DavetKarti(
                    satir: d,
                    gonderiliyor: _gonderiliyor.contains(d.userId),
                    onYenidenGonder: () => _yenidenGonder(d),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TesisKoduKarti extends StatelessWidget {
  const _TesisKoduKarti({required this.kod});

  final String kod;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        key: const Key('davet-tesis-kodu'),
        title: Text(l10n.davetYonTesisKoduIpucu),
        subtitle: SelectableText(
          kod,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        trailing: IconButton(
          tooltip: l10n.davetYonKodKopyala,
          icon: const Icon(Icons.copy_outlined),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: kod));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.davetYonKodKopyalandi)),
              );
            }
          },
        ),
      ),
    );
  }
}

class _DavetKarti extends StatelessWidget {
  const _DavetKarti({
    required this.satir,
    required this.gonderiliyor,
    required this.onYenidenGonder,
  });

  final DavetSatiri satir;
  final bool gonderiliyor;
  final VoidCallback onYenidenGonder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durum = davetDurumu(satir);
    final (etiket, renk) = _durumSunumu(context, durum);
    final gonderim = satir.sonGonderimAt;
    return Card(
      key: Key('davet-${satir.userId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    satir.daireNo == null
                        ? satir.ad
                        : '${satir.ad} · ${satir.daireNo}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  key: Key('davet-durum-${satir.userId}'),
                  visualDensity: VisualDensity.compact,
                  label: Text(etiket),
                  side: BorderSide(color: renk),
                  labelStyle: TextStyle(color: renk),
                ),
              ],
            ),
            if (satir.telefon.isNotEmpty)
              Text(satir.telefon, style: Theme.of(context).textTheme.bodySmall),
            // SEBEP GORUNUR KALIR (web ile ayni): "gonderilemedi" tek basina
            // yoneticiye ne yapacagini soylemiyor.
            if (satir.sonDurum == 'basarisiz' && (satir.sonHata ?? '').isNotEmpty)
              Text(
                satir.sonHata!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (gonderim != null)
              Text(
                l10n.davetYonSonGonderim(
                  tarihSaatBicimi(gonderim.toLocal(), context.dilKodu),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            // Kaydolmus kisiye davet yeniden gonderilmez (sunucu 409).
            if (durum != DavetDurumu.kaydoldu)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: Key('davet-yeniden-${satir.userId}'),
                  onPressed: gonderiliyor ? null : onYenidenGonder,
                  icon: gonderiliyor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(l10n.davetYonYenidenGonder),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Durum -> (etiket, renk). Renk anlami web rozetleriyle ayni:
/// olumlu yesil, kritik kirmizi, bilgi mavi, uyari turuncu.
(String, Color) _durumSunumu(BuildContext context, DavetDurumu d) {
  final l10n = context.l10n;
  final sema = Theme.of(context).colorScheme;
  const olumlu = Color(0xFF16A34A);
  const uyari = Color(0xFFD97706);
  return switch (d) {
    DavetDurumu.kaydoldu => (l10n.davetYonDurumKaydoldu, olumlu),
    DavetDurumu.geriDondu => (l10n.davetYonDurumGeriDondu, sema.error),
    DavetDurumu.gitmedi => (l10n.davetYonDurumGitmedi, sema.error),
    DavetDurumu.ayarYok => (l10n.davetYonDurumAyarYok, sema.error),
    DavetDurumu.acildi => (l10n.davetYonDurumAcildi, olumlu),
    DavetDurumu.iletildi => (l10n.davetYonDurumIletildi, sema.primary),
    DavetDurumu.gonderildi => (l10n.davetYonDurumGonderildi, sema.primary),
    DavetDurumu.bekliyor => (l10n.davetYonDurumBekliyor, uyari),
  };
}
