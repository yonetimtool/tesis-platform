import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../data/tenant_api.dart';
import '../domain/tenant_models.dart';
import '../domain/tesis_ayar_alanlari.dart';
import 'tesis_konumu.dart';

/// (P251 §8) TESIS AYARLARI — mobil Yonetim grubunda (web ikizi
/// `/tesis-ayarlari`).
///
/// Eskiden mobilde yalniz tesis ADI vardi ve Ayarlar ekraninin icindeydi
/// (kisisel ayarlarin arasinda — siteye ait bir ayar). Ad + adres (acik
/// adres, ilce, il, posta kodu) burada.
///
/// (P253 Asama 2) OPERASYON AYARLARI da burada — web `/tesis-ayarlari`
/// ile AYNI tablo ve gruplar (`tesis_ayar_alanlari.dart`): devriye,
/// vardiya, gurultu, finans, rezervasyon, otopark. Yalniz tesis KONUMU
/// bilgisayardan (karo karari bekliyor).
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

  /// Operasyon ayarlarinin METIN/SAYI alanlari (anahtar = sunucu alani).
  late final Map<String, TextEditingController> _op = {
    for (final a in tesisAyarlari)
      if (a.tip == AyarTipi.sayi || a.tip == AyarTipi.metin)
        a.anahtar: TextEditingController(text: '${widget.ayarlar.ham[a.anahtar] ?? ''}'),
  };

  /// bool / secim alanlarinin guncel degeri.
  late final Map<String, Object?> _secili = {
    for (final a in tesisAyarlari)
      if (a.tip == AyarTipi.bool || a.tip == AyarTipi.secim) a.anahtar: widget.ayarlar.ham[a.anahtar],
  };
  bool _gonderiyor = false;

  @override
  void dispose() {
    for (final c in _k.values) {
      c.dispose();
    }
    for (final c in _op.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sayi alaninin hatasi (bos = gecerli: sunucuda "temizle").
  String? _aralikHatasi(TesisAyari a) {
    if (a.tip != AyarTipi.sayi) return null;
    final metin = _op[a.anahtar]!.text.trim();
    if (metin.isEmpty) return null;
    final n = int.tryParse(metin);
    if (n == null || (a.min != null && n < a.min!) || (a.max != null && n > a.max!)) {
      return context.l10n.tsaAralikHatasi(a.min ?? 0, a.max ?? 0);
    }
    return null;
  }

  bool get _hataVar => tesisAyarlari.any((a) => _aralikHatasi(a) != null);

  /// (P253 A2) Sunucudaki konum (yoksa null) ve kullanicinin sectigi.
  SeciliKonum? get _ilkKonum {
    final h = widget.ayarlar.ham;
    final lat = (h['konum_lat'] as num?)?.toDouble();
    final lon = (h['konum_lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return (ad: (h['konum_ad'] as String?) ?? '', lat: lat, lon: lon);
  }

  SeciliKonum? _konum;

  Map<String, Object?> get _degisen {
    final out = <String, Object?>{
      if (_konum != null && _konum != _ilkKonum) ...{
        'konum_ad': _konum!.ad,
        'konum_lat': _konum!.lat,
        'konum_lon': _konum!.lon,
      },
      for (final e in _k.entries)
        if (e.value.text.trim() != _ilk[e.key]!.trim())
          e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
    };
    for (final a in tesisAyarlari) {
      final eski = widget.ayarlar.ham[a.anahtar];
      Object? yeni;
      switch (a.tip) {
        case AyarTipi.sayi:
          final m = _op[a.anahtar]!.text.trim();
          yeni = m.isEmpty ? null : int.tryParse(m);
        case AyarTipi.metin:
          final m = _op[a.anahtar]!.text.trim();
          yeni = m.isEmpty ? null : m;
        case AyarTipi.bool:
        case AyarTipi.secim:
          yeni = _secili[a.anahtar];
      }
      final esitBos = (yeni == null || yeni == '') && (eski == null || eski == '');
      if (yeni != eski && !esitBos) out[a.anahtar] = yeni;
    }
    return out;
  }

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    final degisen = _degisen;
    // Ad bosaltilamaz (sunucu da reddeder; istek atmadan durdurulur).
    if (degisen.isEmpty || _hataVar || (degisen.containsKey('ad') && degisen['ad'] == null)) {
      return;
    }
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

  Widget _ayarAlani(TesisAyari a) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    // Gurultu esigi 1: web ile ayni uyari (sunucu kabul eder, arayuz uyarir).
    final ipucu = a.anahtar == 'gurultu_esigi' && _op[a.anahtar]?.text.trim() == '1'
        ? l10n.tsaAyarGurultuEsikBirUyari
        : a.ipucu?.call(l10n);
    final Widget alan = switch (a.tip) {
      AyarTipi.bool => SwitchListTile(
          key: Key('tesis-ayar-${a.anahtar}'),
          contentPadding: EdgeInsets.zero,
          title: Text(a.etiket(l10n)),
          subtitle: ipucu == null ? null : Text(ipucu, style: TextStyle(fontSize: 12, color: ikincil)),
          value: _secili[a.anahtar] == true,
          onChanged: _gonderiyor ? null : (v) => setState(() => _secili[a.anahtar] = v),
        ),
      AyarTipi.secim => DropdownButtonFormField<String>(
          key: Key('tesis-ayar-${a.anahtar}'),
          isExpanded: true,
          initialValue: _secili[a.anahtar] as String?,
          decoration: InputDecoration(
            labelText: a.etiket(l10n),
            helperText: ipucu,
            helperMaxLines: 6,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final s in a.secenekler)
              DropdownMenuItem(value: s.deger, child: Text(s.etiket(l10n), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _gonderiyor ? null : (v) => setState(() => _secili[a.anahtar] = v),
        ),
      AyarTipi.sayi || AyarTipi.metin => TextField(
          key: Key('tesis-ayar-${a.anahtar}'),
          controller: _op[a.anahtar],
          enabled: !_gonderiyor,
          keyboardType: a.tip == AyarTipi.sayi ? TextInputType.number : null,
          maxLines: a.tip == AyarTipi.metin && (a.azami ?? 0) > 100 ? 3 : 1,
          minLines: 1,
          inputFormatters: GirdiSiniri.sinir(
              a.tip == AyarTipi.sayi ? GirdiSiniri.sayi : (a.azami ?? GirdiSiniri.baslik)),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: a.etiket(l10n),
            helperText: ipucu,
            helperMaxLines: 6,
            errorText: _aralikHatasi(a),
            border: const OutlineInputBorder(),
          ),
        ),
    };
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: alan);
  }

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
        // (P253 A2) Tesis konumu — kendi karo dosyamizla harita + adres
        // aramasi (web ile ayni akis). Deger formun parcasi: Kaydet ile gider.
        const SizedBox(height: 8),
        TesisKonumuBolumu(
          mevcut: _ilkKonum,
          onDegisti: (k) => setState(() => _konum = k),
        ),
        // (P253 Asama 2) OPERASYON AYARLARI — web ile ayni gruplar ve sira.
        for (final g in AyarGrubu.values)
          if (tesisAyarlari.any((a) => a.grup == g)) ...[
            const SizedBox(height: 20),
            Text(ayarGrubuBasligi(l10n, g), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final a in tesisAyarlari.where((a) => a.grup == g)) _ayarAlani(a),
          ],
        const SizedBox(height: 8),
        Text(l10n.tsaTesisAyarPlatformNotu,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('tesis-ayar-kaydet'),
          onPressed: _gonderiyor || _hataVar || _degisen.isEmpty ? null : _kaydet,
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
