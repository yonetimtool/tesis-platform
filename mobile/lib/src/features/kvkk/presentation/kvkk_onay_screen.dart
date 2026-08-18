import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/kvkk_api.dart';
import '../domain/kaydirma_kapisi.dart';
import '../domain/kvkk_models.dart';
import '../../../core/widgets/zengin_govde.dart';

/// Zorunlu aydinlatma kapisi (P36).
///
/// KAYDIRMA KILIDI: "Onaylıyorum" butonu, kullanici metnin SONUNA gelene
/// kadar KAPALIDIR. Bu bir UX susu degil — aydinlatmanin GERCEKTEN
/// gosterildiginin tek istemci-tarafi kanitidir.
///
/// PAZARLAMA IZINLERI AYNI EKRANDA AMA AYRI BIR BLOKTA ve UCU DE KAPALI
/// baslar. Onay butonuyla ayni kutuya koymak, aydinlatma onayini pazarlama
/// rizasiyla KARISTIRIRDI — KVKK'da ikisi FARKLI hukuki temellerdir ve
/// birbirine kosullanamaz (izin vermeden de devam edilebilir).
class KvkkOnayScreen extends ConsumerStatefulWidget {
  const KvkkOnayScreen({super.key});

  @override
  ConsumerState<KvkkOnayScreen> createState() => _KvkkOnayScreenState();
}

class _KvkkOnayScreenState extends ConsumerState<KvkkOnayScreen> {
  final _kaydirma = ScrollController();
  bool _sonaGeldi = false;
  bool _gonderiliyor = false;
  String? _hata;
  PazarlamaTercihleri _tercih = const PazarlamaTercihleri();

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirmaDegisti);
    // Icerik ekrana SIGIYORSA hic kaydirma olayi gelmez ve buton sonsuza
    // dek kapali kalirdi — ilk karede bir kez olculur.
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydirmaDegisti());
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  void _kaydirmaDegisti() {
    if (!_kaydirma.hasClients) return;
    final acik = kaydirmaKapisiAcik(
      kaydirmaKonumu: _kaydirma.position.pixels,
      enBuyukKonum: _kaydirma.position.maxScrollExtent,
    );
    if (acik != _sonaGeldi) setState(() => _sonaGeldi = acik);
  }

  Future<void> _tercihDegistir(String kanal, bool deger) async {
    final oncesi = _tercih;
    setState(() {
      _tercih = switch (kanal) {
        'eposta' => _tercih.copyWith(eposta: deger),
        'sms' => _tercih.copyWith(sms: deger),
        _ => _tercih.copyWith(arama: deger),
      };
    });
    try {
      await ref.read(kvkkApiProvider).tercihGuncelle({kanal: deger});
    } catch (_) {
      // GERI AL: kaydedilmemis bir izni acik gostermek, kullaniciya
      // vermedigi bir rizayi vermis gibi gosterirdi.
      if (!mounted) return;
      setState(() => _tercih = oncesi);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(context.l10n.kvkkIzinKaydedilemedi)));
    }
  }

  Future<void> _onayla(int surum) async {
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await ref.read(kvkkApiProvider).onayla(surum);
      ref.invalidate(kvkkDurumProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 = metin SIZ OKURKEN degisti. Yeni metni cekip kapiyi
      // yeniden kurmak, okumadigi bir metni onaylatmaktan iyidir.
      if (e.statusCode == 409) {
        ref.invalidate(kvkkMetinProvider);
        setState(() {
          _sonaGeldi = false;
          _hata = context.l10n.kvkkSurumDegisti;
        });
      } else {
        setState(() => _hata = e.message);
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metinAsync = ref.watch(kvkkMetinProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kvkkBaslik),
        // GERI TUSU YOK: kapi asilamaz olmali.
        automaticallyImplyLeading: false,
      ),
      body: metinAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Hata(
          mesaj: l10n.kvkkYuklenemedi,
          buton: l10n.kvkkTekrarDene,
          onTap: () => ref.invalidate(kvkkMetinProvider),
        ),
        data: (metin) => SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _kaydirma,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metin.baslik,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      // TENANT ICERIGI: metin orijinal dilinde gosterilir
                      // (cevrilmez — hukuki metnin makine cevirisi yanlis
                      // bir taahhut uretirdi).
                      // (P171) Zengin metin — sunucu yazma aninda temizliyor.
                      // ONAY KAPISINDA bu ozellikle onemli: kullanicinin
                      // ONAYLADIGI metni ham etiketlerle gostermek, neyi
                      // onayladigini bulaniklastirirdi.
                      ZenginGovde(metin.govde),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(l10n.kvkkIzinBaslik,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(l10n.kvkkIzinAciklama,
                          style: Theme.of(context).textTheme.bodySmall),
                      PazarlamaAnahtarlari(
                        tercih: _tercih,
                        onDegis: _tercihDegistir,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_hata != null) ...[
                      Text(_hata!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 8),
                    ],
                    if (!_sonaGeldi)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.kvkkSonaKaydir,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('kvkk-onayla'),
                        onPressed: (!_sonaGeldi || _gonderiliyor)
                            ? null
                            : () => _onayla(metin.surum),
                        child: Text(l10n.kvkkOnayliyorum),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uc BAGIMSIZ pazarlama anahtari — onay ekraninda ve Ayarlar'da AYNI widget
/// (iki yerde iki ayri liste, birinde eklenen kanalin digerinde unutulmasi
/// demekti).
class PazarlamaAnahtarlari extends StatelessWidget {
  const PazarlamaAnahtarlari({
    super.key,
    required this.tercih,
    required this.onDegis,
  });

  final PazarlamaTercihleri tercih;
  final void Function(String kanal, bool deger) onDegis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SwitchListTile(
          key: const Key('pazarlama-eposta'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kvkkIzinEposta),
          value: tercih.eposta,
          onChanged: (v) => onDegis('eposta', v),
        ),
        SwitchListTile(
          key: const Key('pazarlama-sms'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kvkkIzinSms),
          value: tercih.sms,
          onChanged: (v) => onDegis('sms', v),
        ),
        SwitchListTile(
          key: const Key('pazarlama-arama'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kvkkIzinArama),
          value: tercih.arama,
          onChanged: (v) => onDegis('arama', v),
        ),
      ],
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({required this.mesaj, required this.buton, required this.onTap});

  final String mesaj;
  final String buton;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(buton)),
          ],
        ),
      );
}
