/// (P250 §2) ÖDEME KODLARI — yönetici; web penceresiyle PARİTE.
///
/// Mobilde yöneticinin ödeme kodları ekranı HİÇ YOKTU (yalnız sakin kendi
/// kodunu görüyordu). Web ile aynı yetenekler:
///   * her kodun yanında KOPYALA,
///   * satır seçimi + TÜMÜNÜ SEÇ, seçilenlere toplu e-posta,
///   * tek kişiye e-posta,
///   * son e-postanın teslim durumu (gönderildi / iletildi / geri döndü),
///   * yeni eklenen kişi EN ÜSTTE (sunucu sıralar).
///
/// Hız sınırı ve "aynı kişiye kısa sürede tekrar gönderme" koruması
/// SUNUCUDADIR; ekran atlananları sayısıyla bildirir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../data/odeme_kodlari_api.dart';

class OdemeKodlariScreen extends ConsumerStatefulWidget {
  const OdemeKodlariScreen({super.key});

  @override
  ConsumerState<OdemeKodlariScreen> createState() => _OdemeKodlariScreenState();
}

class _OdemeKodlariScreenState extends ConsumerState<OdemeKodlariScreen> {
  List<OdemeKoduSatiri>? _liste;
  String? _hata;
  final Set<String> _secili = {};
  bool _gonderiyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(odemeKodlariApiProvider).listele();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
        _secili.removeWhere((id) => !l.any((s) => s.userId == id));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _hata = apiHataMetni(context.l10n, e));
    }
  }

  List<String> get _secilebilir => [
        for (final s in _liste ?? const <OdemeKoduSatiri>[])
          if (s.epostaEngeli == null) s.userId,
      ];

  Future<void> _gonder(List<String> idler) async {
    if (idler.isEmpty) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _gonderiyor = true);
    try {
      final s = await ref.read(odemeKodlariApiProvider).gonder(idler);
      final mesajlar = [
        if (s.gonderilen > 0) l10n.odemeKoduGonderildiTek,
        if (s.kuyrugaAlinan > 0) l10n.odemeKoduKuyruga('${s.kuyrugaAlinan}'),
        if (s.atlanan > 0) l10n.odemeKoduAtlandi('${s.atlanan}'),
      ];
      if (mesajlar.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(mesajlar.join('\n'))));
      }
      _secili.clear();
      await _yukle();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final liste = _liste;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.odemeKodlariBaslik)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('odeme-kodu-toplu-gonder'),
            onPressed: _gonderiyor || _secili.isEmpty
                ? null
                : () => _gonder(_secili.toList()),
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: Text(l10n.odemeKoduSecilenlereGonder('${_secili.length}')),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
      body: _hata != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_hata!, textAlign: TextAlign.center),
              ),
            )
          : liste == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          l10n.odemeKodlariAciklama,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (liste.isEmpty)
                        BosDurum(
                          ikon: Icons.qr_code_2_outlined,
                          baslik: l10n.odemeKoduBos,
                          aciklama: l10n.odemeKoduBosAciklama,
                        )
                      else ...[
                        CheckboxListTile(
                          key: const Key('odeme-kodu-tumunu-sec'),
                          title: Text(l10n.odemeKoduTumunuSec),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _secilebilir.isNotEmpty &&
                              _secilebilir.every(_secili.contains),
                          onChanged: _secilebilir.isEmpty
                              ? null
                              : (v) => setState(() {
                                    _secili.clear();
                                    if (v ?? false) _secili.addAll(_secilebilir);
                                  }),
                        ),
                        const Divider(height: 1),
                        for (final s in liste)
                          _Satir(
                            satir: s,
                            secili: _secili.contains(s.userId),
                            gonderiyor: _gonderiyor,
                            onSec: (v) => setState(() {
                              if (v) {
                                _secili.add(s.userId);
                              } else {
                                _secili.remove(s.userId);
                              }
                            }),
                            onGonder: () => _gonder([s.userId]),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({
    required this.satir,
    required this.secili,
    required this.gonderiyor,
    required this.onSec,
    required this.onGonder,
  });

  final OdemeKoduSatiri satir;
  final bool secili;
  final bool gonderiyor;
  final ValueChanged<bool> onSec;
  final VoidCallback onGonder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final engel = satir.epostaEngeli;
    final altSatir = [
      satir.daireNo ?? '—',
      satir.ad,
      if (satir.email != null) satir.email!,
    ].join(' · ');
    return Padding(
      key: Key('odeme-kodu-satiri-${satir.userId}'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: secili,
            onChanged: engel != null ? null : (v) => onSec(v ?? false),
            semanticLabel: l10n.odemeKoduSecimEtiketi(satir.ad),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  satir.odemeKodu,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
                Text(altSatir, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                _DurumCipi(durum: satir.epostaDurumu, engel: engel),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.odemeKoduKopyala,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: satir.odemeKodu));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.odemeKoduKopyalandi)),
                );
              }
            },
          ),
          IconButton(
            key: Key('odeme-kodu-gonder-${satir.userId}'),
            tooltip: l10n.odemeKoduEpostaGonderEtiketi(satir.ad),
            icon: const Icon(Icons.outgoing_mail),
            onPressed: gonderiyor || engel != null ? null : onGonder,
          ),
        ],
      ),
    );
  }
}

class _DurumCipi extends StatelessWidget {
  const _DurumCipi({required this.durum, required this.engel});

  final String? durum;
  final String? engel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sema = Theme.of(context).colorScheme;
    final (String metin, Color renk) = switch ((engel, durum)) {
      ('eposta_kapali', _) => (l10n.odemeKoduEngeleposta_kapali, sema.tertiary),
      (String _, _) => (l10n.odemeKoduEngeleposta_yok, sema.tertiary),
      (_, 'kuyrukta') => (l10n.odemeKoduDurumkuyrukta, sema.primary),
      (_, 'gonderildi') => (l10n.odemeKoduDurumgonderildi, sema.primary),
      (_, 'iletildi') => (l10n.odemeKoduDurumiletildi, Colors.green.shade700),
      (_, 'geri_dondu') => (l10n.odemeKoduDurumgeri_dondu, sema.error),
      (_, 'yapilandirilmadi') =>
        (l10n.odemeKoduDurumyapilandirilmadi, sema.tertiary),
      (_, null) => (l10n.odemeKoduHicGonderilmedi, sema.outline),
      _ => (l10n.odemeKoduDurumbasarisiz, sema.error),
    };
    final cip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: renk),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        metin,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: renk),
      ),
    );
    // (P251 §10) Ulasmadiysa NE YAPILACAGI — ham saglayici hatasi yok.
    final aciklama = engel == null ? teslimAciklamasi(l10n, durum) : null;
    if (aciklama == null) return cip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        cip,
        Text(
          aciklama,
          key: const Key('odeme-kodu-teslim-aciklama'),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// (P251 §10) Web `lib/teslim-durumu.ts` ikizi.
String? teslimAciklamasi(AppLocalizations l10n, String? durum) => switch (durum) {
  'geri_dondu' => l10n.teslimAciklama_geri_dondu,
  'basarisiz' => l10n.teslimAciklama_basarisiz,
  'yapilandirilmadi' => l10n.teslimAciklama_yapilandirilmadi,
  _ => null,
};
