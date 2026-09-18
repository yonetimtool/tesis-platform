import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/diyafon_api.dart';
import '../domain/diyafon_models.dart';

/// (P240 §2) DIYAFON — mobil yonetici ekrani.
///
/// =========================================================================
/// YETENEK LISTESI SUNUCUDAN
/// =========================================================================
/// Hangi yontemin ne yapabildigi `yetenekler` alanindan cizilir; eylem
/// dugmeleri de ona gore. Basinca 422 alacak bir dugme gostermek,
/// olmayan bir yetenegi vaat etmek olurdu.
///
/// SESLI ANONS SATIRI HER KAYITTA: "neden ses gelmiyor" sorusu sahada
/// degil SECIM ANINDA yanitlanmali.
class DiyafonEkrani extends ConsumerWidget {
  const DiyafonEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durum = ref.watch(diyafonListeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diyafonBaslik)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.diyafonYeni),
        onPressed: () async {
          final eklendi = await merkezSayfaAc<bool>(
            context,
            builder: (_) => const _DiyafonFormu(),
          );
          if (eklendi ?? false) ref.invalidate(diyafonListeProvider);
        },
      ),
      body: durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (liste) {
          if (liste.isEmpty) {
            return BosDurum(
              ikon: Icons.doorbell_outlined,
              baslik: l10n.diyafonYok,
              aciklama: l10n.diyafonYokAlt,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(diyafonListeProvider),
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _DiyafonKarti(d: liste[i]),
            ),
          );
        },
      ),
    );
  }
}

String diyafonYontemAdi(AppLocalizations l10n, String yontem) => switch (yontem) {
      'sip' => l10n.diyafonYontemSip,
      'sip_kopru' => l10n.diyafonYontemSipKopru,
      'kuru_kontak' => l10n.diyafonYontemKuruKontak,
      _ => yontem,
    };

String diyafonHataMetni(AppLocalizations l10n, String? kod) => switch (kod) {
      'diyafon_reddedildi' => l10n.diyafonHataReddedildi,
      'diyafon_yapilandirma_eksik' => l10n.diyafonHataYapilandirma,
      'diyafon_yontem_desteklemiyor' => l10n.diyafonHataDesteklemiyor,
      _ => l10n.diyafonHataUlasilamiyor,
    };

class _DiyafonKarti extends ConsumerStatefulWidget {
  const _DiyafonKarti({required this.d});

  final Diyafon d;

  @override
  ConsumerState<_DiyafonKarti> createState() => _DiyafonKartiState();
}

class _DiyafonKartiState extends ConsumerState<_DiyafonKarti> {
  bool _mesgul = false;

  Future<void> _eylem(Future<({bool ok, String? kod})> Function() is_) async {
    setState(() => _mesgul = true);
    final l10n = context.l10n;
    final mesajci = ScaffoldMessenger.of(context);
    try {
      final sonuc = await is_();
      mesajci.showSnackBar(SnackBar(
        content: Text(sonuc.ok
            ? l10n.diyafonEylemBasarili
            : diyafonHataMetni(l10n, sonuc.kod)),
      ));
      ref.invalidate(diyafonListeProvider);
    } catch (_) {
      mesajci.showSnackBar(SnackBar(content: Text(l10n.entegBasarisiz)));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.d;
    final api = ref.read(diyafonApiProvider);
    final yetenekler = [
      if (d.yetenekler.metinAnons) l10n.diyafonYetenekMetin,
      if (d.yetenekler.zilCal) l10n.diyafonYetenekZil,
      if (d.yetenekler.kapiAc) l10n.diyafonYetenekKapi,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${diyafonYontemAdi(l10n, d.yontem)} · ${d.host}',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
            yetenekler,
            key: Key('diyafon-yetenek-${d.id}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            l10n.diyafonSesliAnonsYok,
            key: Key('diyafon-sesli-yok-${d.id}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  d.saglik == 'bagli'
                      ? Icons.check_circle_outline
                      : d.saglik == 'hata'
                          ? Icons.error_outline
                          : Icons.help_outline,
                  size: 16,
                  color: d.saglik == 'bagli'
                      ? Colors.green
                      : d.saglik == 'hata'
                          ? Theme.of(context).colorScheme.error
                          : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.saglik == 'bagli'
                        ? l10n.entegSaglikBagli
                        : d.saglik == 'hata'
                            ? '${l10n.entegSaglikHata} — ${diyafonHataMetni(l10n, d.sonHataKod)}'
                            : l10n.entegSaglikBilinmiyor,
                    key: Key('diyafon-saglik-${d.id}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('diyafon-test-${d.id}'),
                icon: const Icon(Icons.network_check, size: 18),
                label: Text(l10n.diyafonTestEt),
                onPressed: _mesgul ? null : () => _eylem(() => api.saglik(d.id)),
              ),
              // EYLEM DUGMELERI YETENEGE GORE: 422 alacak bir dugme
              // gostermek, olmayan bir yetenegi vaat etmek olurdu.
              if (d.yetenekler.zilCal)
                OutlinedButton.icon(
                  key: Key('diyafon-zil-${d.id}'),
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text(l10n.diyafonZil),
                  onPressed: _mesgul ? null : () => _eylem(() => api.zil(d.id)),
                ),
              if (d.yetenekler.kapiAc)
                OutlinedButton.icon(
                  key: Key('diyafon-kapi-${d.id}'),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(l10n.diyafonKapiAc),
                  onPressed: _mesgul
                      ? null
                      : () async {
                          // FIZIKSEL ERISIM: onay ister.
                          final onay = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.diyafonKapiAc),
                              content: Text(l10n.diyafonKapiOnay(d.ad)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(l10n.ortakIptal),
                                ),
                                FilledButton(
                                  key: const Key('diyafon-kapi-onay'),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(l10n.diyafonKapiAc),
                                ),
                              ],
                            ),
                          );
                          if (onay ?? false) await _eylem(() => api.kapiAc(d.id));
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiyafonFormu extends ConsumerStatefulWidget {
  const _DiyafonFormu();

  @override
  ConsumerState<_DiyafonFormu> createState() => _DiyafonFormuState();
}

class _DiyafonFormuState extends ConsumerState<_DiyafonFormu> {
  final _ad = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _kullanici = TextEditingController();
  final _sifre = TextEditingController();
  final _hedef = TextEditingController();
  final _zil = TextEditingController();
  final _kapi = TextEditingController();
  String _yontem = 'sip';
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    // TEK TEK YAZILIYOR, DONGUYLE DEGIL: `denetleyici_atma_test`
    // kaynagi tarayip her denetleyici icin `X.dispose()` ariyor ve
    // donguyu goremiyor. Kilit HAKLI — donguye bir alan eklemeyi
    // unutmak sessiz bir sizinti olurdu; acik liste o riski kaldirir.
    _ad.dispose();
    _host.dispose();
    _port.dispose();
    _kullanici.dispose();
    _sifre.dispose();
    _hedef.dispose();
    _zil.dispose();
    _kapi.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref.read(diyafonApiProvider).olustur(DiyafonTaslak(
            ad: _ad.text.trim(),
            yontem: _yontem,
            host: _host.text.trim(),
            port: int.tryParse(_port.text.trim()),
            kullanici: _kullanici.text.trim().isEmpty ? null : _kullanici.text.trim(),
            sifre: _sifre.text.isEmpty ? null : _sifre.text,
            hedef: _hedef.text.trim().isEmpty ? null : _hedef.text.trim(),
            zilYolu: _zil.text.trim().isEmpty ? null : _zil.text.trim(),
            kapiYolu: _kapi.text.trim().isEmpty ? null : _kapi.text.trim(),
          ));
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kuru = _yontem == 'kuru_kontak';
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.diyafonYeni,
                style: Theme.of(context).textTheme.titleMedium),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_hata!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('diyafon-ad'),
              controller: _ad,
              decoration: InputDecoration(labelText: l10n.kameraAd),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('diyafon-yontem'),
              initialValue: _yontem,
              // YONTEM ADLARI UZUN ("SIP / IP diyafon (2N, Akuvox,
              // Dahua VTO)") ve marka ornekleri SECIM ANINDA degerli.
              // `isExpanded` olmadan satir 211 px TASIYORDU (test
              // yakaladi); kisaltmak yerine KUTUYU genislettik ve
              // tasan kuyruga ucnokta koyduk — acilan menude tam metin
              // yine gorunur.
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.diyafonYontem,
                helperText: l10n.diyafonYontemIpucu,
                helperMaxLines: 2,
              ),
              items: [
                for (final y in ['sip', 'sip_kopru', 'kuru_kontak'])
                  DropdownMenuItem(
                    value: y,
                    child: Text(
                      diyafonYontemAdi(l10n, y),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _mesgul ? null : (v) => setState(() => _yontem = v ?? 'sip'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('diyafon-host'),
              controller: _host,
              decoration: InputDecoration(labelText: l10n.diyafonHost),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('diyafon-port'),
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.diyafonPort,
                helperText: l10n.diyafonPortIpucu,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            // ALANLAR YONTEME GORE: hepsini birden gostermek,
            // doldurmamasi gereken alanlar sunmak olurdu.
            if (kuru) ...[
              TextField(
                key: const Key('diyafon-zil-yolu'),
                controller: _zil,
                decoration: InputDecoration(
                  labelText: l10n.diyafonZilYolu,
                  helperText: l10n.diyafonYolIpucu,
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('diyafon-kapi-yolu'),
                controller: _kapi,
                decoration: InputDecoration(labelText: l10n.diyafonKapiYolu),
              ),
            ] else
              TextField(
                key: const Key('diyafon-hedef'),
                controller: _hedef,
                decoration: InputDecoration(
                  labelText: l10n.diyafonHedef,
                  helperText: l10n.diyafonHedefIpucu,
                  helperMaxLines: 2,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('diyafon-kullanici'),
              controller: _kullanici,
              decoration: InputDecoration(labelText: l10n.diyafonKullanici),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('diyafon-sifre'),
              controller: _sifre,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.diyafonSifre,
                helperText: l10n.diyafonSifreIpucu,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('diyafon-kaydet'),
              onPressed: _mesgul ? null : _kaydet,
              child: Text(l10n.ortakKaydet),
            ),
          ],
        ),
      ),
    );
  }
}
