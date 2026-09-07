import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_api.dart';

/// (DUKKAN F3) ISLETME PROFILI — mobil.
///
/// Web profilinin dar ekran uyarlamasi. Farklar ve gerekceleri:
///   * Iletisim dugmeleri EN USTTE ve tam genislikte — telefonda
///     kullanici once "arayabilir miyim" sorusunu sorar; web'de yan
///     sutunda durabilen bir dugme burada asagi kaydirilirsa bulunmaz.
///   * Hizmet bolgeleri ILCE duzeyinde ozet (uc de oyle donuyor);
///     40 satirlik bir liste telefonda sayfayi bogar.
///   * Rozet aciklamasi ACIK METIN olarak duruyor, ipucu balonu degil:
///     dokunmatikte hover yok ve balon kesfedilmez.
class DukkanProfilScreen extends ConsumerWidget {
  const DukkanProfilScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final gelecek = ref.watch(_profilProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanBaslik)),
      body: gelecek.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(t.dukkanIsletmeBulunamadi)),
        data: (d) => _Govde(d: d),
      ),
    );
  }
}

final _profilProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, slug) => ref.watch(dukkanApiProvider).profil(slug),
);

class _Govde extends StatelessWidget {
  const _Govde({required this.d});

  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final metin = Theme.of(context).textTheme;
    final seviye = (d['dogrulama_seviyesi'] as num?)?.toInt() ?? 0;
    final yorumSayisi = (d['yorum_sayisi'] as num?)?.toInt() ?? 0;
    final puan = d['ortalama_puan'] == null
        ? null
        : double.tryParse('${d['ortalama_puan']}');
    final telefon = '${d['telefon'] ?? ''}';
    final whatsapp = d['whatsapp'] as String?;
    final kategoriler = ((d['kategoriler'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final bolgeler = ((d['hizmet_bolgeleri'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('${d['ad'] ?? ''}', style: metin.headlineSmall),
        const SizedBox(height: 6),
        if (yorumSayisi > 0 && puan != null)
          Text('★ ${puan.toStringAsFixed(1)} '
              '($yorumSayisi ${t.dukkanDegerlendirme})')
        else
          Text(t.dukkanDegerlendirmeYok, style: metin.bodySmall),
        const SizedBox(height: 16),

        // ILETISIM EN USTTE — telefonda ilk soru "arayabilir miyim".
        if (telefon.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:$telefon')),
              icon: const Icon(Icons.call),
              label: Text(telefon),
            ),
          ),
        if (whatsapp != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://wa.me/${whatsapp.replaceAll(RegExp(r"\D"), "")}'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(t.dukkanWhatsapp),
            ),
          ),
        ],

        if (d['aciklama'] != null &&
            '${d['aciklama']}'.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.dukkanHakkinda, style: metin.titleMedium),
          const SizedBox(height: 6),
          Text('${d['aciklama']}'),
        ],

        if (kategoriler.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.dukkanVerdigiHizmetler, style: metin.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in kategoriler) Chip(label: Text('${k['ad']}')),
            ],
          ),
        ],

        if (bolgeler.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.dukkanHizmetBolgeleri, style: metin.titleMedium),
          const SizedBox(height: 6),
          for (final b in bolgeler)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${b['ilce']}, ${b['il']} '
                '(${b['mahalle_sayisi']} ${t.dukkanMahalleSayisi})',
                style: metin.bodySmall,
              ),
            ),
        ],

        // ROZET ACIKLAMASI ACIK METIN: dokunmatikte hover yok, ipucu
        // balonu kesfedilmez. Rozetin ne KANITLAMADIGI da yazili.
        const SizedBox(height: 28),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.dukkanRozetNedir, style: metin.titleSmall),
                const SizedBox(height: 6),
                Text(
                  seviye >= 2 ? t.dukkanRozetSeviye2 : t.dukkanRozetSeviye1,
                  style: metin.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(t.dukkanOdemeUyarisi, style: metin.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
