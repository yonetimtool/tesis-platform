import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_api.dart';
import 'dukkan_telefon_screen.dart';
import '../data/dukkan_oturum.dart';

/// (DUKKAN F4) TALEP OLUSTURMA — KVKK paylasim tercihleri merkezi.
///
/// =========================================================================
/// DAR EKRANA UYARLAMA
/// =========================================================================
/// Web'de form tek sayfa; telefonda o form uzun bir kaydirma olur ve
/// paylasim tercihleri EN ALTTA, kullanicinin gormeden gectigi yerde
/// kalirdi. Burada ADIM ADIM:
///   1) hizmet + bolge
///   2) ihtiyac metni
///   3) PAYLASIM TERCIHLERI — kendi ekraninda, gonder dugmesiyle birlikte
///
/// Ucuncu adimin ayri ekran olmasi bilincli: kullanici "ne paylasiyorum"
/// sorusunu KENDI EKRANINDA gorup karar versin. Formun dibine iliksirilmis
/// uc onay kutusu, telefonda okunmadan gecilirdi.
class DukkanTalepOlusturScreen extends ConsumerStatefulWidget {
  const DukkanTalepOlusturScreen({super.key, this.kategoriSlug});

  final String? kategoriSlug;

  @override
  ConsumerState<DukkanTalepOlusturScreen> createState() =>
      _DukkanTalepOlusturScreenState();
}

class _DukkanTalepOlusturScreenState
    extends ConsumerState<DukkanTalepOlusturScreen> {
  int _adim = 0;
  String? _kategori;
  String? _il;
  String? _ilce;
  String? _mahalle;
  List<Map<String, String>> _ilceler = const [];
  List<Map<String, String>> _mahalleler = const [];

  final _aciklama = TextEditingController();
  final _adres = TextEditingController();
  bool _paylasAd = false;
  bool _paylasTelefon = false;
  bool _paylasAdres = false;
  bool _bekle = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kategori = widget.kategoriSlug;
  }

  @override
  void dispose() {
    _aciklama.dispose();
    _adres.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    setState(() {
      _bekle = true;
      _hata = null;
    });
    try {
      // JETON ONCE ALINIR (SSO koprusu). Telefonu olmayan kullanicida
      // 409 `telefon_gerekli` gelir — bu KENAR DURUM DEGIL: olculdu,
      // Yonetiyor kullanicilarinin %27'sinde telefon yok. Kullaniciya
      // ne oldugu ACIKCA soyleniyor.
      final jeton = await ref.read(dukkanOturumProvider).jetonAl();
      final sonuc = await ref.read(dukkanApiProvider).talepOlustur(
            jeton: jeton,
            kategoriSlug: _kategori!,
            ilSlug: _il!,
            ilceSlug: _ilce!,
            mahalleSlug: _mahalle!,
            aciklama: _aciklama.text.trim(),
            paylasAd: _paylasAd,
            paylasTelefon: _paylasTelefon,
            paylasAdres: _paylasAdres,
            acikAdres: _adres.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(dukkanTaleplerimProvider);
      final t = AppLocalizations.of(context);
      // TALEP KIMSEYE ULASMADIYSA BUNU SOYLUYORUZ — sessizce "gonderildi"
      // deyip 0 isletmeye giden bir talep kullaniciyi bos yere bekletirdi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sonuc.eslesen == 0
              ? t.dukkanTalepUlasmadi
              : t.dukkanTalepGonderildi(sonuc.eslesen)),
          duration: const Duration(seconds: 6),
        ),
      );
      context.go('/dukkan/taleplerim');
    } on DukkanOturumHatasi catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      if (e.kod == 'telefon_gerekli') {
        // (F7 §2) COZUMU OLAN BIR HATA, METIN DEGIL AKIS.
        //
        // Buraya kadar gelen kullanici formu DOLDURMUS durumda; ona
        // "web'e gidin" demek, girdigi her seyi cope atmasini istemekti.
        // Telefon dogrulama ekrani acilir ve basariliysa GONDERIM
        // KALDIGI YERDEN tekrarlanir.
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const DukkanTelefonScreen()),
        );
        if (ok == true && mounted) {
          setState(() => _bekle = false);
          return _gonder();
        }
        setState(() => _hata = t.dukkanTelefonAciklama);
      } else {
        setState(() => _hata = t.dukkanListeAlinamadi);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final kategoriler = ref.watch(dukkanKategorilerProvider);
    final iller = ref.watch(dukkanIllerProvider);
    final api = ref.read(dukkanApiProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanTeklifAl)),
      body: Stepper(
        currentStep: _adim,
        onStepContinue: () {
          if (_adim == 0 &&
              (_kategori == null || _il == null || _ilce == null ||
                  _mahalle == null)) {
            return;
          }
          if (_adim == 1 && _aciklama.text.trim().length < 10) return;
          if (_adim == 2) {
            _gonder();
            return;
          }
          setState(() => _adim++);
        },
        onStepCancel: _adim == 0 ? null : () => setState(() => _adim--),
        controlsBuilder: (context, ayrinti) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _bekle ? null : ayrinti.onStepContinue,
                  child: Text(_adim == 2 ? t.dukkanTalebiGonder : t.dukkanDevam),
                ),
              ),
              if (_adim > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: ayrinti.onStepCancel,
                  child: Text(t.dukkanGeri),
                ),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: Text(t.dukkanHizmetSec),
            isActive: _adim >= 0,
            content: Column(
              children: [
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
                const SizedBox(height: 12),
                iller.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _il,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanBolgeSec,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final i in list)
                        DropdownMenuItem(value: i['slug'], child: Text(i['ad']!)),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _il = v;
                        _ilce = null;
                        _mahalle = null;
                        _ilceler = const [];
                        _mahalleler = const [];
                      });
                      if (v != null) {
                        final l = await api.ilceler(v);
                        if (mounted) setState(() => _ilceler = l);
                      }
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(t.dukkanListeAlinamadi),
                ),
                if (_ilceler.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _ilce,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanTumIlceler,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final i in _ilceler)
                        DropdownMenuItem(value: i['slug'], child: Text(i['ad']!)),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _ilce = v;
                        _mahalle = null;
                        _mahalleler = const [];
                      });
                      if (v != null && _il != null) {
                        final l = await api.mahalleler(_il!, v);
                        if (mounted) setState(() => _mahalleler = l);
                      }
                    },
                  ),
                ],
                if (_mahalleler.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _mahalle,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.dukkanMahalleSayisi,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in _mahalleler)
                        DropdownMenuItem(value: m['slug'], child: Text(m['ad']!)),
                    ],
                    onChanged: (v) => setState(() => _mahalle = v),
                  ),
                ],
              ],
            ),
          ),
          Step(
            title: Text(t.dukkanIhtiyacin),
            isActive: _adim >= 1,
            content: TextField(
              controller: _aciklama,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: t.dukkanIhtiyacinIpucu,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // ============================================================ //
          // ADIM 3: PAYLASIM TERCIHLERI — KENDI EKRANINDA
          // ============================================================ //
          // Formun dibine iliksirilmis uc onay kutusu telefonda
          // okunmadan gecilirdi. Kullanici "ne paylasiyorum" sorusunu
          // KENDI EKRANINDA gorup karar versin.
          Step(
            title: Text(t.dukkanNeGorecek),
            isActive: _adim >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Gorunur(metin: t.dukkanMahallenGorunur),
                _Gorunur(metin: t.dukkanAciklamaGorunur),
                const Divider(height: 24),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paylasAd,
                  onChanged: (v) => setState(() => _paylasAd = v ?? false),
                  title: Text(t.dukkanAdimiPaylas),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paylasTelefon,
                  onChanged: (v) => setState(() => _paylasTelefon = v ?? false),
                  title: Text(t.dukkanTelefonumuPaylas),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paylasAdres,
                  onChanged: (v) => setState(() => _paylasAdres = v ?? false),
                  title: Text(t.dukkanAdresimiPaylas),
                  subtitle: Text(t.dukkanAdresIpucu,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                if (_paylasAdres)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _adres,
                      decoration: InputDecoration(
                        labelText: t.dukkanAcikAdres,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  )
                else
                  // IZIN VERILMEDIYSE ADRESIN HIC SAKLANMADIGINI SOYLUYORUZ.
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t.dukkanAdresSaklanmaz,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (_hata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_hata!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gorunur extends StatelessWidget {
  const _Gorunur({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
                child: Text(metin,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}
