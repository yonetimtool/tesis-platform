import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../routing/app_router.dart';
import '../data/dukkan_api.dart';

/// (DUKKAN F3) YEREL ISLETMELER — arama ve liste.
///
/// =========================================================================
/// DAR EKRANA UYARLANDI, KOPYALANMADI
/// =========================================================================
/// Web'de suzgecler yan yana bir satirda duruyor; telefonda o satir
/// okunmaz hale gelirdi. Burada:
///   * suzgecler DIKEY ve daraltilabilir bir bolumde,
///   * her kartta EN ONEMLI eylem (ARA) bas parmak menzilinde ve tam
///     genislikte — web'de kucuk bir dugme yeterliyken telefonda arama
///     asil donusum ve dokunma hedefi 48dp'den kucuk olmamali,
///   * aciklama iki satirla kirpiliyor: telefonda uzun metin listeyi
///     kaydirilmaz yapar.
class DukkanAramaScreen extends ConsumerStatefulWidget {
  const DukkanAramaScreen({super.key});

  @override
  ConsumerState<DukkanAramaScreen> createState() => _DukkanAramaScreenState();
}

class _DukkanAramaScreenState extends ConsumerState<DukkanAramaScreen> {
  final _aramaKontrol = TextEditingController();
  String? _kategori;
  String? _il;
  String? _ilce;
  List<Map<String, String>> _ilceler = const [];
  Future<DukkanAramaSonucu>? _sonuc;

  @override
  void dispose() {
    _aramaKontrol.dispose();
    super.dispose();
  }

  void _ara() {
    setState(() {
      _sonuc = ref.read(dukkanApiProvider).ara(
            il: _il,
            ilce: _ilce,
            kategori: _kategori,
            q: _aramaKontrol.text.trim(),
          );
    });
  }

  Future<void> _ilceleriYukle(String ilSlug) async {
    final l = await ref.read(dukkanApiProvider).ilceler(ilSlug);
    if (mounted) setState(() => _ilceler = l);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final kategoriler = ref.watch(dukkanKategorilerProvider);
    final iller = ref.watch(dukkanIllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.dukkanBaslik),
        // (F6-ek) DUKKAN'IN UC KIMLIKLI YUZEYINE GIRIS BURADAN.
        //
        // Ana ekranda AYRI KART ACILMADI: "Yerel isletmeler" tek kart
        // olarak duruyor ve alt yuzeyler bu ekrandan aciliyor. Uc kart
        // daha eklemek, pazar yerini hic kullanmayan cogunluga uc olu
        // kutu gostermek olurdu (ana ekran zaten yogun — P184'te
        // kucultme calismasi yapildi).
        actions: [
          IconButton(
            tooltip: t.dukkanTaleplerim,
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () => context.push(AppRoutes.dukkanTaleplerim),
          ),
          IconButton(
            tooltip: t.dukkanPanelBaslik,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push(AppRoutes.dukkanPanel),
          ),
          IconButton(
            tooltip: t.dukkanBildirimler,
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(AppRoutes.dukkanBildirim),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _aramaKontrol,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _ara(),
                  decoration: InputDecoration(
                    hintText: t.dukkanAra,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // SUZGECLER DIKEY: web'deki yatay satir telefonda okunmaz.
                kategoriler.when(
                  data: (ks) => DropdownButtonFormField<String>(
                    initialValue: _kategori,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanHizmetSec,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final ana in ks)
                        for (final alt in ana.alt)
                          DropdownMenuItem(
                            value: alt.slug,
                            child: Text('${ana.ad} · ${alt.ad}',
                                overflow: TextOverflow.ellipsis),
                          ),
                    ],
                    onChanged: (v) => setState(() => _kategori = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(t.dukkanListeAlinamadi),
                ),
                const SizedBox(height: 8),
                iller.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _il,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanBolgeSec,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(t.dukkanTumIller)),
                      for (final i in list)
                        DropdownMenuItem(value: i['slug'], child: Text(i['ad']!)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _il = v;
                        _ilce = null;
                        _ilceler = const [];
                      });
                      if (v != null) _ilceleriYukle(v);
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(t.dukkanListeAlinamadi),
                ),
                if (_ilceler.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _ilce,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanTumIlceler,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(t.dukkanTumIlceler)),
                      for (final i in _ilceler)
                        DropdownMenuItem(value: i['slug'], child: Text(i['ad']!)),
                    ],
                    onChanged: (v) => setState(() => _ilce = v),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _ara,
                    child: Text(t.dukkanAra),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _sonucAlani(context, t)),
        ],
      ),
    );
  }

  Widget _sonucAlani(BuildContext context, AppLocalizations t) {
    if (_sonuc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.dukkanAra, textAlign: TextAlign.center),
        ),
      );
    }
    return FutureBuilder<DukkanAramaSonucu>(
      future: _sonuc,
      builder: (context, anlik) {
        if (anlik.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (anlik.hasError) {
          // SESSIZ BASARISIZLIK YOK: bos liste cizmek "sonuc yok" gibi
          // okunur ve kullaniciya YANLIS bilgi verirdi.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.dukkanListeAlinamadi),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _ara, child: Text(t.dukkanTekrarDene)),
              ],
            ),
          );
        }
        final d = anlik.data!;
        if (d.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.dukkanSonucYok, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(t.dukkanSonucYokIpucu,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        }
        // (F8) SPONSORLU BLOK ORGANIK LISTENIN USTUNDE, AYRI.
        //
        // Tek listeye karistirmak, kullanicinin "en iyi sonuc" sandigi
        // seyi satmak olurdu — ve o an organik listenin degeri duser,
        // dolayisiyla reklamin degeri de duser. Ayrim sunucuda basliyor
        // (`items` / `sponsorlu` ayri anahtarlar), arayuz onu SURDURUYOR.
        final hepsi = [...d.sponsorlu, ...d.items];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: hepsi.length,
          separatorBuilder: (_, n) =>
              // Sponsorlu blogun SONUNDA gorsel ayirac: iki blok arasinda
              // bosluk birakmak, rozetin tek ayirt edici olmasini onler.
              n == d.sponsorlu.length - 1 && d.sponsorlu.isNotEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 16),
                    )
                  : const SizedBox(height: 8),
          itemBuilder: (_, n) => _IsletmeKarti(isletme: hepsi[n]),
        );
      },
    );
  }
}

class _IsletmeKarti extends StatelessWidget {
  const _IsletmeKarti({required this.isletme});

  final DukkanIsletme isletme;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      // SPONSORLU KART GORSEL OLARAK AYRI: rozet tek basina yetmez,
      // hizli kaydiran kullanici onu okumaz.
      color: isletme.sponsorlu ? scheme.tertiaryContainer : null,
      child: InkWell(
        onTap: () => context.push('/dukkan/isletme/${isletme.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (F8) "Sponsorlu" ROZETI ZORUNLU — reklamin reklam
              // oldugu acikca belli olmali (07-hukuki-sorular S18).
              if (isletme.sponsorlu)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    t.dukkanSponsorlu,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              Text(isletme.ad,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isletme.yorumSayisi > 0 && isletme.ortalamaPuan != null)
                    Text(
                      '★ ${isletme.ortalamaPuan!.toStringAsFixed(1)} '
                      '(${isletme.yorumSayisi} ${t.dukkanDegerlendirme})',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(t.dukkanDegerlendirmeYok,
                        style: Theme.of(context).textTheme.bodySmall),
                  if (isletme.dogrulamaSeviyesi >= 2)
                    _Rozet(
                        metin: t.dukkanDogrulanmisIsletme,
                        renk: scheme.primaryContainer,
                        yazi: scheme.onPrimaryContainer)
                  else if (isletme.dogrulamaSeviyesi == 1)
                    _Rozet(
                        metin: t.dukkanTelefonDogrulandi,
                        renk: scheme.surfaceContainerHighest,
                        yazi: scheme.onSurfaceVariant),
                ],
              ),
              if (isletme.kategoriler.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(isletme.kategoriler.take(3).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              if (isletme.aciklama != null &&
                  isletme.aciklama!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                // IKI SATIRLA KIRPILIYOR: telefonda uzun metin listeyi
                // kaydirilmaz hale getirir.
                Text(isletme.aciklama!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              // ARA DUGMESI TAM GENISLIK: telefonda asil donusum arama ve
              // dokunma hedefi bas parmak menzilinde olmali.
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                          Uri.parse('tel:${isletme.telefon}')),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text(t.dukkanAra2),
                    ),
                  ),
                  if (isletme.whatsapp != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => launchUrl(
                          Uri.parse(
                              'https://wa.me/${isletme.whatsapp!.replaceAll(RegExp(r"\D"), "")}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(t.dukkanWhatsapp),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  const _Rozet({required this.metin, required this.renk, required this.yazi});

  final String metin;
  final Color renk;
  final Color yazi;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
        child: Text(metin,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: yazi)),
      );
}
