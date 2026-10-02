import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../data/tenant_api.dart';
import '../domain/tenant_models.dart';

/// (P251 §8) TESIS AYARLARI — mobil Yonetim grubunda (web ikizi
/// `/tesis-ayarlari`).
///
/// Eskiden mobilde yalniz tesis ADI vardi ve Ayarlar ekraninin icindeydi
/// (kisisel ayarlarin arasinda — siteye ait bir ayar). Onayli oneri:
/// tesis ayarlarinin METIN alanlari mobilde de. Ad + adres (acik adres,
/// ilce, il, posta kodu) burada; konum (harita), otopark kapasitesi ve
/// esikler bilgisayardan (gerekce `contracts/menu-paritesi.tsv`).
///
/// YALNIZ DEGISEN alan gonderilir (web ekraniyla ayni sozlesme).
class TesisAyarlariScreen extends ConsumerWidget {
  const TesisAyarlariScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(tenantSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.modulTesisAyarlari, context.dilKodu))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata),
        ),
        data: (t) => _Form(ayarlar: t),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.ayarlar});
  final TenantSettings ayarlar;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  /// Sunucu-tarafi yer tutucu — kullaniciya gosterilmez, alan bos baslar.
  static const _yerTutucu = '(Kurulum bekliyor)';

  late final Map<String, TextEditingController> _k = {
    'ad': TextEditingController(
        text: widget.ayarlar.ad == _yerTutucu ? '' : widget.ayarlar.ad),
    'adres': TextEditingController(text: widget.ayarlar.adres ?? ''),
    'ilce': TextEditingController(text: widget.ayarlar.ilce ?? ''),
    'il': TextEditingController(text: widget.ayarlar.il ?? ''),
    'posta_kodu': TextEditingController(text: widget.ayarlar.postaKodu ?? ''),
  };
  late final Map<String, String> _ilk = {for (final e in _k.entries) e.key: e.value.text};
  bool _gonderiyor = false;

  @override
  void dispose() {
    for (final c in _k.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _degisen => {
        for (final e in _k.entries)
          if (e.value.text.trim() != _ilk[e.key]!.trim())
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      };

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    final degisen = _degisen;
    // Ad bosaltilamaz (sunucu da reddeder; istek atmadan durdurulur).
    if (degisen.isEmpty || (degisen.containsKey('ad') && degisen['ad'] == null)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _gonderiyor = true);
    try {
      await ref.read(tenantApiProvider).guncelle(degisen);
      ref.invalidate(tenantSettingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.tesisAyarKaydedildi)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } catch (_) {
      // Beklenmeyen hata ekrani DUSURMEZ; genel mesaj (Ayarlar'daki eski
      // tesis adi kartinin davranisi korundu).
      messenger.showSnackBar(SnackBar(content: Text(l10n.ortakBeklenmeyenHata)));
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
    }
  }

  Widget _alan(String ad, String etiket, int sinir, {TextInputType? klavye, IconData? ikon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key('tesis-ayar-$ad'),
          controller: _k[ad],
          enabled: !_gonderiyor,
          keyboardType: klavye,
          inputFormatters: GirdiSiniri.sinir(sinir),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: etiket,
            prefixIcon: ikon == null ? null : Icon(ikon),
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.tesisAdiAciklama,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _alan('ad', l10n.ayarlarTesisAdi, GirdiSiniri.baslik, ikon: Icons.business_outlined),
        _alan('adres', l10n.tesisAyarAdres, GirdiSiniri.adres, ikon: Icons.place_outlined),
        _alan('ilce', l10n.tesisAyarIlce, 100),
        _alan('il', l10n.tesisAyarIl, 100),
        _alan('posta_kodu', l10n.tesisAyarPostaKodu, 5, klavye: TextInputType.number),
        Text(l10n.tesisAyarWebNotu,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('tesis-ayar-kaydet'),
          onPressed: _gonderiyor || _degisen.isEmpty ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _gonderiyor
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(l10n.ortakKaydet),
        ),
      ],
    );
  }
}
