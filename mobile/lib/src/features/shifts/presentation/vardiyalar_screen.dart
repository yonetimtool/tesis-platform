import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';
import '../data/shifts_api.dart';
import '../domain/shift_models.dart';
import 'gun_tipi_adi.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/bos_durum.dart';

/// Vardiyalar ekrani (WP-E) — tum vardiya tanimlari + atanan personel.
/// admin/yonetici her vardiyaya "Personel Ata" ile saha personeli atar
/// (tam-liste degistirme); diger roller salt-okur. Hata ekrani DUSURMEZ.
class VardiyalarScreen extends ConsumerWidget {
  const VardiyalarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsProvider);
    final rol = UserRole.fromClaim(ref.watch(profileProvider).value?.role ?? '');
    final atayabilir =
        rol == UserRole.admin || rol == UserRole.yonetici;

    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.vardiyaBaslik, context.dilKodu)),
      ),
      // (P253 Asama 1) Sablon ekle/duzenle/sil — web `SablonBolumu` ile
      // AYNI uclar (`/shifts`), yalniz admin+yonetici (sunucu `_ADMIN`).
      floatingActionButton: atayabilir
          ? FloatingActionButton.extended(
              key: const Key('vardiya-sablon-ekle'),
              icon: const Icon(Icons.add),
              label: Text(l10n.vrdSablonEkle),
              onPressed: () => _sablonFormu(context, ref, null),
            )
          : null,
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? apiHataMetni(l10n, e) : l10n.vardiyaYuklenemedi,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (vardiyalar) {
          if (vardiyalar.isEmpty) {
            return BosDurum(
              ikon: Icons.schedule_outlined,
              baslik: l10n.vardiyaTanimYok,
              aciklama: l10n.vardiyaTanimYokAlt,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: vardiyalar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = vardiyalar[i];
              final personelAdlari = v.personel.map((p) => p.ad).join(', ');
              return Card(
                child: ListTile(
                  key: Key('vardiya-sablon-${v.id}'),
                  onTap: atayabilir ? () => _sablonFormu(context, ref, v) : null,
                  title: Text(v.ad),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.vardiyaSaatAraligi(
                        v.baslangicSaat,
                        v.bitisSaat,
                        gunTipiAdi(l10n, v.gunTipi),
                      )),
                      if (v.personel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            personelAdlari,
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: v.personel.isNotEmpty,
                  trailing: atayabilir
                      // GENISLIK SINIRI: `ListTile`in trailing'i tum satiri
                      // yerse Flutter LAYOUT ASSERTION'i atar ("Trailing
                      // widget consumes the entire tile width") — 320 dp'de
                      // uzun ceviriyle tam bu oluyordu (tur 50). Etiket
                      // korunur, gerekirse kisalir.
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: TextButton(
                            onPressed: () => _atamaSheet(context, ref, v),
                            child: Text(
                              l10n.vardiyaPersonelAta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _sablonFormu(
      BuildContext context, WidgetRef ref, Shift? vardiya) async {
    final mesaj = await showDialog<String>(
      context: context,
      builder: (_) => SablonFormu(vardiya: vardiya),
    );
    if (mesaj == null) return;
    ref.invalidate(shiftsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  void _atamaSheet(BuildContext context, WidgetRef ref, Shift vardiya) {
    merkezSayfaAc<void>(
      context,
      builder: (_) => _AtamaSheet(vardiya: vardiya),
    );
  }
}

class _AtamaSheet extends ConsumerStatefulWidget {
  const _AtamaSheet({required this.vardiya});

  final Shift vardiya;

  @override
  ConsumerState<_AtamaSheet> createState() => _AtamaSheetState();
}

class _AtamaSheetState extends ConsumerState<_AtamaSheet> {
  late final Set<String> _secili = {
    for (final p in widget.vardiya.personel) p.userId,
  };
  bool _kaydediyor = false;

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _kaydediyor = true);
    try {
      await ref
          .read(shiftsApiProvider)
          .updateAssignments(widget.vardiya.id, _secili.toList());
      ref.invalidate(shiftsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.vardiyaPersonelGuncellendi)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _kaydediyor = false);
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personelAsync = ref.watch(atanabilirPersonelProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.vardiyaPersonelBaslik(widget.vardiya.ad),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            Flexible(
              child: personelAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      e is ApiException
                          ? apiHataMetni(l10n, e)
                          : l10n.vardiyaPersonelYuklenemedi),
                ),
                data: (personel) {
                  if (personel.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.vardiyaAtanabilirYok),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in personel)
                        CheckboxListTile(
                          value: _secili.contains(p.userId),
                          title: Text(p.ad),
                          onChanged: _kaydediyor
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _secili.add(p.userId);
                                    } else {
                                      _secili.remove(p.userId);
                                    }
                                  }),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _kaydediyor ? null : _kaydet,
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _kaydediyor
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(l10n.ortakKaydet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// (P253 Asama 1) Sablon ekle / duzenle / sil. Donus: sonuc metni (degismediyse null).
const gunTipleri = <String>['her_gun', 'hafta_ici', 'hafta_sonu', 'resmi_tatil'];

class SablonFormu extends ConsumerStatefulWidget {
  const SablonFormu({super.key, this.vardiya});

  /// null = yeni sablon.
  final Shift? vardiya;

  @override
  ConsumerState<SablonFormu> createState() => _SablonFormuState();
}

class _SablonFormuState extends ConsumerState<SablonFormu> {
  late final _adCtrl = TextEditingController(text: widget.vardiya?.ad ?? '');
  late TimeOfDay _bas = _saat(widget.vardiya?.baslangicSaat, 8);
  late TimeOfDay _son = _saat(widget.vardiya?.bitisSaat, 16);
  late String _gunTipi = widget.vardiya?.gunTipi ?? gunTipleri.first;
  String? _hata;
  bool _bekliyor = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay _saat(String? hhmm, int varsayilan) {
    final p = (hhmm ?? '').split(':');
    final h = p.isNotEmpty ? int.tryParse(p[0]) : null;
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    return TimeOfDay(hour: h ?? varsayilan, minute: m ?? 0);
  }

  String _s(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _calistir(
      Future<void> Function(ShiftsApi api) is_, String basari) async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await is_(ref.read(shiftsApiProvider));
      if (mounted) Navigator.of(context).pop(basari);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bekliyor = false;
        _hata = apiHataMetni(context.l10n, e);
      });
    }
  }

  Future<void> _kaydet() {
    final ad = _adCtrl.text.trim();
    final v = widget.vardiya;
    final basari = context.l10n.vrdSablonKaydedildi;
    return _calistir((api) async {
      if (v == null) {
        await api.olustur(
            ad: ad, baslangicSaat: _s(_bas), bitisSaat: _s(_son), gunTipi: _gunTipi);
      } else {
        await api.guncelle(v.id,
            ad: ad, baslangicSaat: _s(_bas), bitisSaat: _s(_son), gunTipi: _gunTipi);
      }
    }, basari);
  }

  Future<void> _sil() async {
    final v = widget.vardiya!;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l10n.vrdSablonSilOnay(v.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            key: const Key('vardiya-sablon-sil-onayla'),
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (ok == true) await _calistir((api) => api.sil(v.id), l10n.vrdSablonSilindi);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.vardiya == null ? l10n.vrdSablonEkle : l10n.vrdSablonDuzenle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hata != null)
              Text(_hata!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextField(
              key: const Key('vardiya-sablon-ad'),
              controller: _adCtrl,
              maxLength: 100, // sunucu: ShiftCreate.ad (_G.AD)
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.vrdSablonAd),
            ),
            ListTile(
              key: const Key('vardiya-sablon-bas'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vardiyaBaslangicSaati),
              trailing: Text(_s(_bas)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _bas);
                if (t != null) setState(() => _bas = t);
              },
            ),
            ListTile(
              key: const Key('vardiya-sablon-son'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vardiyaBitisSaati),
              trailing: Text(_s(_son)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _son);
                if (t != null) setState(() => _son = t);
              },
            ),
            DropdownButtonFormField<String>(
              key: const Key('vardiya-sablon-gun-tipi'),
              isExpanded: true,
              initialValue: _gunTipi,
              decoration: InputDecoration(labelText: l10n.vrdGunTipi),
              items: [
                for (final g in gunTipleri)
                  DropdownMenuItem(value: g, child: Text(gunTipiAdi(l10n, g))),
              ],
              onChanged: (v) => setState(() => _gunTipi = v ?? _gunTipi),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.vardiya != null)
          TextButton(
            key: const Key('vardiya-sablon-sil'),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: _bekliyor ? null : _sil,
            child: Text(l10n.vrdSablonSil),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('vardiya-sablon-kaydet'),
          onPressed: _bekliyor || _adCtrl.text.trim().isEmpty ? null : _kaydet,
          child: Text(l10n.ortakKaydet),
        ),
      ],
    );
  }
}
