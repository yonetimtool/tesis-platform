import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../announcements/data/announcement_api.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/tatbikat_api.dart';
import '../domain/panik_models.dart';
import 'panik_alarm_ekrani.dart';
import 'panik_sayfasi.dart' show panikKategoriAdi;

/// (P249 §2) TATBIKATLAR — planla, baslat, bitir, raporla.
///
/// YONETIM planlar ve yonetir; GUVENLIK raporu okur (sayimi o yapar).
/// Rapor ekrandaki "daire bazinda durum" ile AYNI kaynaktan gelir
/// (`PanikDurumPaneli`); PDF WEB'DEDIR — bkz. docs §2 parite notu.
class TatbikatEkrani extends ConsumerWidget {
  const TatbikatEkrani({super.key});

  /// Toplu uyari kategorileri — tatbikat YALNIZ bunlarda (sunucu da zorlar).
  static const kategoriler = [
    PanikKategori.deprem,
    PanikKategori.yangin,
    PanikKategori.gaz,
    PanikKategori.tahliye,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value;
    final yonetim = rol == UserRole.yonetici || rol == UserRole.admin;
    final liste = ref.watch(tatbikatListeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tatbikatBaslik)),
      floatingActionButton: yonetim
          ? FloatingActionButton.extended(
              key: const Key('tatbikat-planla'),
              icon: const Icon(Icons.add_alert),
              label: Text(l10n.tatbikatPlanla),
              // Alt sayfa DEGIL: depo kurali (merkez_diyalog_test).
              onPressed: () => merkezSayfaAc<void>(
                context,
                builder: (_) => const TatbikatFormu(),
              ),
            )
          : null,
      body: liste.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (l) => l.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.tatbikatYok, textAlign: TextAlign.center),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(tatbikatListeProvider),
                child: ListView.separated(
                  itemCount: l.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _Satir(t: l[i], yonetim: yonetim),
                ),
              ),
      ),
    );
  }
}

String tatbikatDurumAdi(BuildContext context, String durum) {
  final l10n = context.l10n;
  return switch (durum) {
    'planli' => l10n.tatbikatDurumPlanli,
    'aktif' => l10n.tatbikatDurumAktif,
    'bitti' => l10n.tatbikatDurumBitti,
    _ => l10n.tatbikatDurumIptal,
  };
}

String tatbikatZamanMetni(DateTime? t) {
  if (t == null) return '';
  final y = t.toLocal();
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${iki(y.day)}.${iki(y.month)}.${y.year} ${iki(y.hour)}:${iki(y.minute)}';
}

class _Satir extends ConsumerWidget {
  const _Satir({required this.t, required this.yonetim});

  final Tatbikat t;
  final bool yonetim;

  Future<void> _eylem(BuildContext context, WidgetRef ref, String eylem) async {
    try {
      await ref.read(tatbikatApiProvider).eylem(t.id, eylem);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    ref.invalidate(tatbikatListeProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kapsam = t.kapsam == 'blok' ? (t.blok ?? '') : l10n.tatbikatKapsamSite;
    final zaman = tatbikatZamanMetni(t.basladiAt ?? t.planlananAt);
    return ListTile(
      key: Key('tatbikat-satir-${t.id}'),
      leading: Icon(
        Icons.campaign_outlined,
        color: t.durum == 'aktif' ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(t.baslik),
      subtitle: Text([
        kapsam,
        zaman,
        tatbikatDurumAdi(context, t.durum),
        if (t.bitisNedeni == 'gercek_alarm') l10n.tatbikatGercekAlarmlaDurdu,
        if (t.duyuruGonderildi) l10n.tatbikatDuyuruGitti,
      ].where((x) => x.isNotEmpty).join(' · ')),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (yonetim && t.durum == 'planli')
            TextButton(
              key: Key('tatbikat-baslat-${t.id}'),
              onPressed: () => _eylem(context, ref, 'baslat'),
              child: Text(l10n.tatbikatBaslat),
            ),
          if (yonetim && t.durum == 'aktif')
            TextButton(
              key: Key('tatbikat-bitir-${t.id}'),
              onPressed: () => _eylem(context, ref, 'bitir'),
              child: Text(l10n.tatbikatBitir),
            ),
          if (yonetim && t.durum == 'planli')
            TextButton(
              key: Key('tatbikat-iptal-${t.id}'),
              onPressed: () => _eylem(context, ref, 'iptal'),
              child: Text(l10n.tatbikatIptal),
            ),
        ],
      ),
      onTap: t.alarmId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TatbikatRaporEkrani(id: t.id)),
              ),
    );
  }
}

/// (P249 §2) RAPOR — kac kisiye gitti, kaci acti, kaci guvende, ortalama
/// yanit suresi, daire bazinda kim yanit vermedi.
class TatbikatRaporEkrani extends ConsumerWidget {
  const TatbikatRaporEkrani({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tatbikatRapor)),
      body: ref.watch(tatbikatRaporProvider(id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (r) => ListView(
              padding: const EdgeInsets.only(top: 12),
              children: [
                ListTile(
                  title: Text(r.tatbikat.baslik,
                      style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Text([
                    r.tatbikat.kapsam == 'blok'
                        ? (r.tatbikat.blok ?? '')
                        : l10n.tatbikatKapsamSite,
                    tatbikatZamanMetni(r.tatbikat.basladiAt),
                    tatbikatDurumAdi(context, r.tatbikat.durum),
                    l10n.tatbikatPushKabul(r.pushGonderildi, r.pushDenenen),
                  ].where((x) => x.isNotEmpty).join(' · ')),
                ),
                if (r.tatbikat.alarmId != null)
                  PanikDurumPaneli(
                    key: const Key('tatbikat-rapor-durum'),
                    alarmId: r.tatbikat.alarmId!,
                  ),
              ],
            ),
          ),
    );
  }
}

/// (P249 §2) PLANLA — zaman bossa HEMEN baslar.
class TatbikatFormu extends ConsumerStatefulWidget {
  const TatbikatFormu({super.key});

  @override
  ConsumerState<TatbikatFormu> createState() => _TatbikatFormuState();
}

class _TatbikatFormuState extends ConsumerState<TatbikatFormu> {
  PanikKategori _kategori = PanikKategori.deprem;
  String _kapsam = 'site';
  String? _blok;
  DateTime? _zaman;
  bool _duyuru = false;
  bool _mesgul = false;
  final _not = TextEditingController();

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _zamanSec() async {
    final simdi = DateTime.now();
    final gun = await showDatePicker(
      context: context,
      initialDate: simdi,
      firstDate: simdi,
      lastDate: simdi.add(const Duration(days: 365)),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(simdi.add(const Duration(hours: 1))),
    );
    if (saat == null) return;
    setState(() => _zaman = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute));
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await ref.read(tatbikatApiProvider).planla(
            kategori: _kategori.kimlik,
            kapsam: _kapsam,
            blok: _kapsam == 'blok' ? _blok : null,
            planlananAt: _zaman,
            duyuru: _zaman != null && _duyuru,
            aciklama: _not.text.trim(),
          );
      ref.invalidate(tatbikatListeProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloklar = ref.watch(duyuruBlokAdlariProvider).value ?? const <String>[];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.tatbikatPlanla, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<PanikKategori>(
              key: const Key('tatbikat-kategori'),
              initialValue: _kategori,
              decoration: InputDecoration(labelText: l10n.tatbikatTur),
              items: [
                for (final k in TatbikatEkrani.kategoriler)
                  DropdownMenuItem(value: k, child: Text(panikKategoriAdi(l10n, k))),
              ],
              onChanged: (k) => setState(() => _kategori = k ?? _kategori),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('tatbikat-kapsam'),
              segments: [
                ButtonSegment(value: 'site', label: Text(l10n.tatbikatKapsamSite)),
                if (bloklar.isNotEmpty)
                  ButtonSegment(value: 'blok', label: Text(l10n.tatbikatKapsamBlok)),
              ],
              selected: {_kapsam},
              onSelectionChanged: (s) => setState(() => _kapsam = s.first),
            ),
            if (_kapsam == 'blok')
              DropdownButtonFormField<String>(
                key: const Key('tatbikat-blok'),
                initialValue: _blok,
                decoration: InputDecoration(labelText: l10n.tatbikatBlok),
                items: [
                  for (final b in bloklar) DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (b) => setState(() => _blok = b),
              ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('tatbikat-zaman'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l10n.tatbikatZaman),
              subtitle: Text(_zaman == null ? l10n.tatbikatHemenUyari : tatbikatZamanMetni(_zaman!)),
              onTap: _zamanSec,
              trailing: _zaman == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _zaman = null),
                    ),
            ),
            if (_zaman != null)
              SwitchListTile(
                key: const Key('tatbikat-duyuru'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.tatbikatDuyuru),
                value: _duyuru,
                onChanged: (v) => setState(() => _duyuru = v),
              ),
            TextField(
              controller: _not,
              maxLength: GirdiSiniri.not_,
              decoration: InputDecoration(labelText: l10n.tatbikatAciklama),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('tatbikat-kaydet'),
              onPressed: _mesgul || (_kapsam == 'blok' && _blok == null) ? null : _kaydet,
              child: Text(_zaman == null ? l10n.tatbikatBaslat : l10n.tatbikatPlanla),
            ),
          ],
        ),
      ),
    );
  }

}
