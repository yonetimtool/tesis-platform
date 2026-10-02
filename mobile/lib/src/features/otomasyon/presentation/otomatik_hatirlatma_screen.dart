/// (P250 §7) OTOMATİK AİDAT HATIRLATMASI — mobil (web otomasyon kartının
/// ikizi; AYNI ayar kaydı, iki yüzeyde farklı ayar olamaz).
///
///   * düz cümleyle özet ("Son ödeme gününden 3, 10, 30 gün sonra ..."),
///   * aç/kapat, e-posta da gönder,
///   * "X gün sonra, Y kez, Z günde bir" (üçü birlikte kaydedilir),
///   * hatırlatma e-postaları — teslim durumuyla.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/hatirlatma_api.dart';
import 'hatirlatma_cumlesi.dart';

class OtomatikHatirlatmaScreen extends ConsumerStatefulWidget {
  const OtomatikHatirlatmaScreen({super.key});

  @override
  ConsumerState<OtomatikHatirlatmaScreen> createState() =>
      _OtomatikHatirlatmaScreenState();
}

class _OtomatikHatirlatmaScreenState
    extends ConsumerState<OtomatikHatirlatmaScreen> {
  final _ilk = TextEditingController();
  final _tekrar = TextEditingController();
  final _aralik = TextEditingController();
  bool _dolduruldu = false;
  bool _kaydediyor = false;

  @override
  void dispose() {
    _ilk.dispose();
    _tekrar.dispose();
    _aralik.dispose();
    super.dispose();
  }

  Future<void> _yaz(Map<String, dynamic> govde) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _kaydediyor = true);
    try {
      await ref.read(hatirlatmaApiProvider).guncelle(govde);
      ref.invalidate(hatirlatmaAyariProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Widget _sayi(String etiket, TextEditingController k, String anahtar) =>
      Expanded(
        child: TextField(
          key: Key(anahtar),
          controller: k,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            labelText: etiket,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ayar = ref.watch(hatirlatmaAyariProvider);
    final epostalar = ref.watch(hatirlatmaEpostalariProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.otoHatirlatma)),
      body: ayar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.ortakBeklenmeyenHata)),
        data: (a) {
          if (!_dolduruldu) {
            _ilk.text = '${a.ilkGun ?? 3}';
            _tekrar.text = '${a.tekrarSayisi == 0 ? 3 : a.tekrarSayisi}';
            _aralik.text = '${a.aralikGun ?? 7}';
            _dolduruldu = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.otoHatirlatmaAciklama,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    hatirlatmaCumlesi(l10n, a),
                    key: const Key('hatirlatma-cumlesi'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              SwitchListTile(
                key: const Key('hatirlatma-aktif'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.otoAktif),
                value: a.aktif,
                onChanged: (v) => _yaz({'aktif': v}),
              ),
              SwitchListTile(
                key: const Key('hatirlatma-eposta'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.otoHatirlatmaEposta),
                value: a.eposta,
                onChanged: (v) => _yaz({'eposta': v}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _sayi(l10n.otoHatirlatmaIlkGun, _ilk, 'hatirlatma-ilk'),
                  const SizedBox(width: 8),
                  _sayi(l10n.otoHatirlatmaTekrar, _tekrar, 'hatirlatma-tekrar'),
                  const SizedBox(width: 8),
                  _sayi(l10n.otoHatirlatmaAralik, _aralik, 'hatirlatma-aralik'),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('hatirlatma-plan-kaydet'),
                onPressed: _kaydediyor
                    ? null
                    : () => _yaz({
                        'ilk_gun': int.tryParse(_ilk.text) ?? 0,
                        'tekrar_sayisi': (int.tryParse(_tekrar.text) ?? 1)
                            .clamp(1, 6),
                        'aralik_gun': (int.tryParse(_aralik.text) ?? 1).clamp(
                          1,
                          60,
                        ),
                      }),
                child: Text(l10n.ortakKaydet),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.otoHatirlatmaKimeNotu,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 32),
              Text(
                l10n.otoEpostaGecmisi,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              epostalar.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (l) => l.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l10n.otoEpostaGecmisiBos),
                      )
                    : Column(
                        children: [
                          for (final e in l)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.ad ?? '—'),
                              subtitle: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatShortDate(e.zaman),
                              ),
                              trailing: Text(_durumMetni(l10n, e.durum)),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _durumMetni(AppLocalizations l10n, String d) => switch (d) {
  'kuyrukta' => l10n.odemeKoduDurumkuyrukta,
  'gonderildi' => l10n.odemeKoduDurumgonderildi,
  'iletildi' => l10n.odemeKoduDurumiletildi,
  'geri_dondu' => l10n.odemeKoduDurumgeri_dondu,
  'yapilandirilmadi' => l10n.odemeKoduDurumyapilandirilmadi,
  _ => l10n.odemeKoduDurumbasarisiz,
};
