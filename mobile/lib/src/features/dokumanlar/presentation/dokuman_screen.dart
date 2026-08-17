import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/dokuman_api.dart';
import '../domain/dokuman_models.dart';

/// (P167 ek) SITE DOKUMANLARI — sakin gorunumu.
///
/// =========================================================================
/// EKRAN NEYI GOSTERIR, NEYI GOSTERMEZ
/// =========================================================================
/// Yalnizca yoneticinin SAKINE ACTIGI dosyalar. Suzgec SUNUCUDA
/// (`GET /me/dokumanlar`); bu ekran hicbir gorunurluk karari VERMEZ.
/// Istemcide "acik mi" diye ikinci bir suzgec yazsaydik, o suzgec bir gun
/// yanlis yazildiginda kapali bir belge ekranda gorunurdu.
///
/// YONETIM UCUNA (`/dokumanlar`) HIC DOKUNULMAZ — o uc TUM arsivi doner.
///
/// =========================================================================
/// DOSYA UYGULAMADA ACILMAZ, SISTEME DEVREDILIR
/// =========================================================================
/// PDF/Word/Excel goruntuleyici GOMULMEDI: her bicim icin bir okuyucu
/// tasimak, uygulamayi buyutur ve bicimlerin cogunda yine de eksik kalirdi.
/// Baglanti sistemin varsayilan uygulamasina verilir — kullanicinin zaten
/// tanidigi ve guvendigi araca.
final _dokumanlarProvider = FutureProvider.autoDispose<List<SiteDokumani>>((
  ref,
) {
  return ref.watch(dokumanApiProvider).fetchAll();
});

class DokumanScreen extends ConsumerStatefulWidget {
  const DokumanScreen({super.key});

  @override
  ConsumerState<DokumanScreen> createState() => _DokumanScreenState();
}

class _DokumanScreenState extends ConsumerState<DokumanScreen> {
  String _sorgu = '';

  /// Hangi satirin baglantisi bekleniyor — iki kez dokunmayi engeller ve
  /// "bir sey oluyor mu" sorusunu yanitlar.
  String? _bekleyenId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durum = ref.watch(_dokumanlarProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dokumanBaslik),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_dokumanlarProvider),
          ),
        ],
      ),
      body: durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Hata(
          mesaj: e is ApiException
              ? apiHataMetni(l10n, e)
              : akisHataMetni(l10n, AkisHatasi.beklenmeyen),
          yenile: () => ref.invalidate(_dokumanlarProvider),
        ),
        data: (hepsi) {
          final liste = _sorgu.isEmpty
              ? hepsi
              : [for (final d in hepsi) if (d.adEslesir(_sorgu)) d];

          return Column(
            children: [
              // ARAMA yalniz LISTE VARSA cizilir: bos bir arsivde arama
              // kutusu, aranacak bir sey varmis izlenimi verirdi.
              if (hepsi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.dokumanAra,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _sorgu = v),
                  ),
                ),
              Expanded(
                child: hepsi.isEmpty
                    ? _Bos(mesaj: l10n.dokumanYokSakin)
                    : liste.isEmpty
                    ? _Bos(mesaj: l10n.dokumanAramaSonucYok)
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(_dokumanlarProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: liste.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = liste[i];
                            return ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: Text(d.ad),
                              subtitle: Text(_altBilgi(context, d)),
                              trailing: _bekleyenId == d.id
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.open_in_new),
                              onTap: _bekleyenId == null ? () => _ac(d) : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tarih + (varsa) boyut. Boyut YOKSA yazilmaz — "0 KB" yazmak, dosyanin
  /// bos oldugunu soylemek olurdu; oysa yalnizca boyutu KAYITLI degil.
  String _altBilgi(BuildContext context, SiteDokumani d) {
    final l10n = context.l10n;
    final tarih = MaterialLocalizations.of(
      context,
    ).formatMediumDate(d.createdAt.toLocal());
    if (d.boyutBayt == null) return tarih;
    final kb = (d.boyutBayt! / 1024).round();
    return '$tarih · ${l10n.dokumanBoyutKb(kb)}';
  }

  Future<void> _ac(SiteDokumani d) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _bekleyenId = d.id);
    try {
      final url = await ref.read(dokumanApiProvider).indirmeBaglantisi(d.id);
      // SESSIZ BASARISIZLIK YOK: acilamazsa kullanici dokundugunu ama
      // hicbir sey olmadigini gorurdu — denetimde "olu dugme" sayilir.
      final acildi = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
      if (!acildi) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.dokumanAcilamadi)),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiHataMetni(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _bekleyenId = null);
    }
  }
}

class _Bos extends StatelessWidget {
  const _Bos({required this.mesaj});

  final String mesaj;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // KAYDIRILABILIR kalir ki "asagi cek yenile" bos listede de calissin.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            children: [
              const Icon(Icons.folder_open_outlined, size: 48),
              const SizedBox(height: 12),
              Text(mesaj, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({required this.mesaj, required this.yenile});

  final String mesaj;
  final VoidCallback yenile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: yenile,
              child: Text(context.l10n.ortakYenile),
            ),
          ],
        ),
      ),
    );
  }
}
