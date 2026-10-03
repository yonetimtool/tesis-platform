/// (P252 §1) CALISMA BILGILERI — personel ekleme formu, satir duzenlemesi
/// ve kisinin KENDI profili.
///
/// Web (`components/kisiler/calisma-bilgileri.tsx`) ile AYNI alanlar ve
/// AYNI kurallar: ucret girilirse odeme gunu ZORUNLU (gunsuz ucret
/// otomasyona hic girmez); hepsi bossa yalniz hesap acilir. Maas karti TEK
/// kaynak — Finans › Maas kartlari ayni satiri gosterir.
///
/// YETKI SUNUCUDA: amir bu bolumu hic gormez (ekran cizmez) ve gonderse
/// de sunucu 403 doner.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../finans/data/finans_api.dart';
import '../../finans/domain/finans_models.dart';
import '../data/staff_api.dart';

final calismaKasalariProvider = FutureProvider.autoDispose<List<Kasa>>(
  (ref) => ref.watch(finansApiProvider).kasalar(),
);

final benimCalismamProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.watch(staffApiProvider).benimCalismam(),
);

/// Formun durumu. Denetleyiciler cagiranin omrune bagli (dispose eder).
class CalismaDegeri {
  final gorevKtrl = TextEditingController();
  final ucretKtrl = TextEditingController();
  final ibanKtrl = TextEditingController();
  final notKtrl = TextEditingController();
  DateTime? giris;
  int? gun;
  String? kasaId;

  void kartiYukle(Map<String, dynamic>? k) {
    if (k == null) return;
    final g = k['giris_tarihi'] as String?;
    giris = g == null ? null : DateTime.tryParse(g);
    gorevKtrl.text = (k['gorev'] as String?) ?? '';
    final m = k['maas_kurus'] as int?;
    ucretKtrl.text = m == null ? '' : tlTutar(m);
    gun = k['odeme_gunu'] as int?;
    kasaId = k['kasa_id'] as String?;
    ibanKtrl.text = (k['iban'] as String?) ?? '';
    notKtrl.text = (k['notlar'] as String?) ?? '';
  }

  bool get bos =>
      giris == null &&
      gun == null &&
      kasaId == null &&
      [gorevKtrl, ucretKtrl, ibanKtrl, notKtrl].every((c) => c.text.trim().isEmpty);

  /// `(govde, hata)` — hepsi bossa govde `null` (yalniz hesap).
  (Map<String, dynamic>?, String?) govde(AppLocalizations l10n) {
    if (bos) return (null, null);
    int? maas;
    if (ucretKtrl.text.trim().isNotEmpty) {
      maas = tlMetniniKurusaCevir(ucretKtrl.text);
      if (maas == null) return (null, l10n.calismaUcretGecersiz);
      if (gun == null) return (null, l10n.calismaGunGerekli);
    }
    final iban = ibanKtrl.text.replaceAll(' ', '').toUpperCase();
    final g = giris;
    return (
      {
        'giris_tarihi': g == null
            ? null
            : '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}',
        'gorev': gorevKtrl.text.trim().isEmpty ? null : gorevKtrl.text.trim(),
        'maas_kurus': maas,
        'odeme_gunu': gun,
        'kasa_id': kasaId,
        'iban': iban.isEmpty ? null : iban,
        'notlar': notKtrl.text.trim().isEmpty ? null : notKtrl.text.trim(),
      },
      null,
    );
  }

  void dispose() {
    gorevKtrl.dispose();
    ucretKtrl.dispose();
    ibanKtrl.dispose();
    notKtrl.dispose();
  }
}

class CalismaAlanlari extends ConsumerStatefulWidget {
  const CalismaAlanlari({super.key, required this.deger, this.etkin = true});

  final CalismaDegeri deger;
  final bool etkin;

  @override
  ConsumerState<CalismaAlanlari> createState() => _CalismaAlanlariState();
}

class _CalismaAlanlariState extends ConsumerState<CalismaAlanlari> {
  CalismaDegeri get d => widget.deger;

  Future<void> _girisSec() async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: d.giris ?? simdi,
      firstDate: DateTime(simdi.year - 50),
      lastDate: DateTime(simdi.year + 1, 12, 31),
    );
    if (secilen != null) setState(() => d.giris = secilen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kasalar = ref.watch(calismaKasalariProvider);
    final giris = d.giris;
    return Column(
      key: const Key('calisma-bilgileri'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.calismaBaslik, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.calismaAlt, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        InkWell(
          key: const Key('calisma-giris'),
          onTap: widget.etkin ? _girisSec : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.calismaGiris,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(giris == null ? '' : tarihBicimi(giris, context.dilKodu)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calisma-gorev'),
          controller: d.gorevKtrl,
          enabled: widget.etkin,
          inputFormatters: GirdiSiniri.sinir(GirdiSiniri.ad),
          decoration: InputDecoration(
            labelText: l10n.calismaGorev,
            hintText: l10n.calismaGorevIpucu,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calisma-ucret'),
          controller: d.ucretKtrl,
          enabled: widget.etkin,
          inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.calismaUcret),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          key: const Key('calisma-gun'),
          initialValue: d.gun,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.calismaOdemeGunu,
            helperText: l10n.calismaOdemeGunuKurali,
            helperMaxLines: 3,
          ),
          items: [
            DropdownMenuItem<int?>(child: Text(l10n.calismaGunSecilmedi)),
            for (var g = 1; g <= 31; g++)
              DropdownMenuItem<int?>(value: g, child: Text('$g')),
          ],
          onChanged: widget.etkin ? (v) => setState(() => d.gun = v) : null,
        ),
        const SizedBox(height: 12),
        kasalar.when(
          data: (ks) => DropdownButtonFormField<String?>(
            key: const Key('calisma-kasa'),
            initialValue: ks.any((k) => k.id == d.kasaId) ? d.kasaId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.calismaKasa),
            items: [
              DropdownMenuItem<String?>(child: Text(l10n.calismaKasaVarsayilan)),
              for (final k in ks)
                DropdownMenuItem<String?>(value: k.id, child: Text(k.ad)),
            ],
            onChanged: widget.etkin ? (v) => setState(() => d.kasaId = v) : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calisma-iban'),
          controller: d.ibanKtrl,
          enabled: widget.etkin,
          inputFormatters: GirdiSiniri.sinir(GirdiSiniri.iban),
          decoration: InputDecoration(labelText: l10n.calismaIban),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calisma-not'),
          controller: d.notKtrl,
          enabled: widget.etkin,
          minLines: 1,
          maxLines: 3,
          inputFormatters: GirdiSiniri.sinir(GirdiSiniri.not_),
          decoration: InputDecoration(labelText: l10n.calismaNot),
        ),
      ],
    );
  }
}

/// Satirdaki "Calisma bilgileri" — bagli karti acar; yoksa olusturur.
class CalismaSayfasi extends ConsumerStatefulWidget {
  const CalismaSayfasi({super.key, required this.kisi});

  final StaffMember kisi;

  @override
  ConsumerState<CalismaSayfasi> createState() => _CalismaSayfasiState();
}

class _CalismaSayfasiState extends ConsumerState<CalismaSayfasi> {
  final _deger = CalismaDegeri();
  String? _kartId;
  bool _yuklendi = false;
  bool _kaydediyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final k = await ref.read(staffApiProvider).calismaKarti(widget.kisi.id);
      if (!mounted) return;
      setState(() {
        _deger.kartiYukle(k);
        _kartId = k?['id'] as String?;
        _yuklendi = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(context.l10n, e);
        _yuklendi = true;
      });
    }
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final (govde, hata) = _deger.govde(l10n);
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _kaydediyor = true;
      _hata = null;
    });
    try {
      await ref.read(staffApiProvider).calismaKaydet(
            kartId: _kartId,
            kisi: widget.kisi,
            govde: govde ?? const {'maas_kurus': null, 'odeme_gunu': null},
          );
      if (!mounted) return;
      navigator.pop('ok');
      messenger.showSnackBar(SnackBar(content: Text(l10n.calismaKaydedildi)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(l10n, e);
        _kaydediyor = false;
      });
    }
  }

  @override
  void dispose() {
    _deger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (!_yuklendi) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.kisi.ad, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          CalismaAlanlari(deger: _deger, etkin: !_kaydediyor),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _hata!,
                key: const Key('calisma-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('calisma-kaydet'),
            onPressed: _kaydediyor ? null : _kaydet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(l10n.ortakKaydet),
          ),
        ],
      ),
    );
  }
}

/// Profilde "Calisma bilgilerim" — personelin KENDI ucreti ve son
/// odemeleri (salt okunur; TC/IBAN/kasa YOK). Karti yoksa hic cizilmez.
class BenimCalismamKarti extends ConsumerWidget {
  const BenimCalismamKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final c = ref.watch(benimCalismamProvider).value;
    if (c == null) return const SizedBox.shrink();
    final maas = c['maas_kurus'] as int?;
    final gun = c['odeme_gunu'] as int?;
    final gorev = c['gorev'] as String?;
    final giris = DateTime.tryParse((c['giris_tarihi'] as String?) ?? '');
    final odemeler =
        ((c['odemeler'] as List?) ?? const []).whereType<Map>().toList();
    Widget satir(String etiket, String deger) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(etiket)),
              Text(deger, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Card(
      key: const Key('benim-calismam'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.calismaBenimBaslik,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (gorev != null) satir(l10n.calismaGorev, gorev),
            if (giris != null) satir(l10n.calismaGiris, tarihBicimi(giris, dil)),
            if (maas != null) satir(l10n.calismaUcret, tlIsaretli(maas, dil)),
            if (gun != null) satir(l10n.calismaOdemeGunu, l10n.calismaOdemeGunuDeger(gun)),
            const Divider(height: 24),
            Text(l10n.calismaSonOdemeler,
                style: Theme.of(context).textTheme.labelLarge),
            if (odemeler.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.calismaOdemeYok),
              ),
            for (final o in odemeler)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(odemeTuruAdi(l10n, o['tur'] as String?)),
                subtitle: Text([
                  tarihBicimi(DateTime.parse(o['tarih'] as String), dil),
                  if (o['durum'] == 'onay_bekliyor') l10n.calismaOnayBekliyor,
                ].join(' · ')),
                trailing: Text(tlIsaretli(o['tutar_kurus'] as int, dil)),
              ),
          ],
        ),
      ),
    );
  }
}

String odemeTuruAdi(AppLocalizations l10n, String? tur) => switch (tur) {
      'maas' => l10n.calismaTurMaas,
      'mesai' => l10n.calismaTurMesai,
      _ => l10n.calismaTurDiger,
    };
