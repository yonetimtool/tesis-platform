/// (P250 §4) KURULUM VİDEOLARI — mobil TAM EKRAN sayfa (açılır pencere değil).
///
///   * Video ÜSTTE; cihaz yatay çevrilince tam ekran (oynatıcı paketi).
///   * Video alanı sağa/sola KAYDIRILARAK adımlar arası geçilir (PageView).
///   * Altında adımlar DİKEY LİSTE: numara, başlık, kısa açıklama, izlendi.
///   * "Şimdi bu adımı yap" ALTTA SABİT; video bitince vurgulanır (dolgulu).
///   * Video BİTİNCE (ENDED) adım hesaba "izlendi" yazılır — ortada
///     kapatılan video izlendi sayılmaz.
///   * Videosu olmayan adım "yakında" — kırık oynatıcı yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../kurulum/presentation/kurulum_screen.dart';
import '../data/egitim_api.dart';
import 'egitim_oynatici.dart';

class KurulumVideolariScreen extends ConsumerStatefulWidget {
  const KurulumVideolariScreen({super.key, this.baslangic});

  /// Sayfa bu adımda açılır (sihirbazdaki "Videoyu izle").
  final String? baslangic;

  @override
  ConsumerState<KurulumVideolariScreen> createState() =>
      _KurulumVideolariScreenState();
}

class _KurulumVideolariScreenState
    extends ConsumerState<KurulumVideolariScreen> {
  PageController? _sayfa;
  int _sira = 0;
  bool _bitti = false;
  String? _hata;

  void _konumla(EgitimListe l) {
    if (_sayfa != null) return;
    var i = widget.baslangic == null
        ? -1
        : l.adimlar.indexWhere((a) => a.adimKodu == widget.baslangic);
    if (i < 0) i = l.adimlar.indexWhere((a) => a.video != null && !a.izlendi);
    _sira = i < 0 ? 0 : i;
    _sayfa = PageController(initialPage: _sira);
  }

  @override
  void dispose() {
    _sayfa?.dispose();
    super.dispose();
  }

  void _git(int i, int adet) {
    if (i < 0 || i >= adet) return;
    _sayfa?.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _videoBitti(EgitimAdim adim) async {
    setState(() => _bitti = true);
    try {
      await ref.read(egitimApiProvider).izlendi(adim.adimKodu);
      ref.invalidate(egitimListesiProvider);
    } catch (_) {
      // İşaret yazılamazsa video yine izlendi; sonraki izlemede yeniden denenir.
    }
  }

  String _baslik(EgitimAdim a) {
    final l10n = context.l10n;
    return a.video?.baslik ??
        kurulumHedefleri[a.adimKodu]?.baslik(l10n) ??
        l10n.egitimAdimBilinmeyen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final liste = ref.watch(egitimListesiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.egitimVideolariBaslik)),
      body: liste.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.egitimVideoErisilemiyor,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (l) {
          _konumla(l);
          final adimlar = l.adimlar;
          if (adimlar.isEmpty) return const SizedBox.shrink();
          final kurucu = ref.watch(egitimOynaticiProvider);
          return LayoutBuilder(
            builder: (context, kisit) {
              // 16:9 ama ekranin YARISINDAN uzun degil: genis/kisa ekranda
              // (tablet, yatay) liste ve dugme gorunur kalsin. Yatay cevrilen
              // telefonda oynaticinin kendisi tam ekrana gecer.
              final videoYuksekligi = (kisit.maxWidth * 9 / 16).clamp(
                0.0,
                kisit.maxHeight * 0.5,
              );
              return Column(
                children: [
                  SizedBox(
                    height: videoYuksekligi,
                    child: PageView.builder(
                      key: const Key('egitim-sayfalar'),
                      controller: _sayfa,
                      itemCount: adimlar.length,
                      onPageChanged: (i) => setState(() {
                        _sira = i;
                        _bitti = false;
                        _hata = null;
                      }),
                      itemBuilder: (context, i) {
                        final a = adimlar[i];
                        final v = a.video;
                        // YALNIZ GORUNEN sayfa oynatici kurar: komsu sayfalar
                        // icin ayri WebView acmak bellegi bosuna tuketirdi.
                        if (v == null || i != _sira) {
                          return _VideoYeri(
                            metin: v == null ? l10n.egitimYakinda : _baslik(a),
                            anahtar: v == null ? 'egitim-yakinda' : null,
                          );
                        }
                        if (_hata != null) {
                          return _VideoYeri(
                            metin: switch (_hata) {
                              'kapali' => l10n.egitimVideoKapali,
                              'erisilemiyor' => l10n.egitimVideoErisilemiyor,
                              _ => l10n.egitimVideoOynatilamadi,
                            },
                            anahtar: 'egitim-hata',
                          );
                        }
                        return kurucu(
                          videoId: v.youtubeId,
                          onBitti: () => _videoBitti(a),
                          onHata: (tur) => setState(() => _hata = tur),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('egitim-geri'),
                          tooltip: l10n.egitimOnceki,
                          onPressed: _sira > 0
                              ? () => _git(_sira - 1, adimlar.length)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            l10n.egitimKaydirIpucu,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          key: const Key('egitim-ileri'),
                          tooltip: l10n.egitimSonraki,
                          onPressed: _sira < adimlar.length - 1
                              ? () => _git(_sira + 1, adimlar.length)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('egitim-adim-listesi'),
                      itemCount: adimlar.length,
                      itemBuilder: (context, i) {
                        final a = adimlar[i];
                        final secili = i == _sira;
                        final renk = Theme.of(context).colorScheme;
                        return ListTile(
                          key: Key('egitim-adim-${a.adimKodu}'),
                          selected: secili,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: secili
                                ? renk.primary
                                : renk.surfaceContainerHighest,
                            foregroundColor: secili
                                ? renk.onPrimary
                                : renk.onSurfaceVariant,
                            child: Text('${i + 1}'),
                          ),
                          title: Text(_baslik(a)),
                          subtitle: Text(
                            a.video == null
                                ? l10n.egitimYakinda
                                : (a.video!.aciklama ?? ''),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: a.izlendi
                              ? Icon(
                                  Icons.check_circle,
                                  color: renk.primary,
                                  semanticLabel: l10n.egitimIzlendi,
                                )
                              : null,
                          onTap: () => _git(i, adimlar.length),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: liste.maybeWhen(
        data: (l) {
          if (l.adimlar.isEmpty) return null;
          final adim = l.adimlar[_sira.clamp(0, l.adimlar.length - 1)];
          final rota = kurulumHedefleri[adim.adimKodu]?.rota;
          final etiket = rota == null
              ? l10n.kurulumAdimWebde
              : l10n.egitimSimdiYap;
          void git() {
            if (rota == null) return;
            // Yonlendirici ONCE alinir: pop sonrasi bu ekranin baglami
            // artik agacta degildir.
            final yonlendirici = GoRouter.of(context);
            yonlendirici.pop();
            yonlendirici.push(rota);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              // VIDEO BITINCE VURGULU: dolgulu birincil dugme; oncesinde
              // cerceveli (ikincil) — goz once videoya baksin.
              child: _bitti
                  ? FilledButton(
                      key: const Key('egitim-simdi-yap'),
                      onPressed: rota == null ? null : git,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(etiket, textAlign: TextAlign.center),
                    )
                  : OutlinedButton(
                      key: const Key('egitim-simdi-yap'),
                      onPressed: rota == null ? null : git,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(etiket, textAlign: TextAlign.center),
                    ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _VideoYeri extends StatelessWidget {
  const _VideoYeri({required this.metin, this.anahtar});

  final String metin;
  final String? anahtar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anahtar == null ? null : Key(anahtar!),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(metin, textAlign: TextAlign.center),
    );
  }
}
