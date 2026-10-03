import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../data/takvim_api.dart';
import '../domain/takvim_models.dart';

String hatTekrarAdi(AppLocalizations l10n, String t) => switch (t) {
      'gunluk' => l10n.hatTekrarGunluk,
      'haftalik' => l10n.hatTekrarHaftalik,
      'aylik' => l10n.hatTekrarAylik,
      _ => l10n.hatTekrarYok,
    };

String hatRenkAdi(AppLocalizations l10n, String r) => switch (r) {
      'yesil' => l10n.hatRenkYesil,
      'turuncu' => l10n.hatRenkTuruncu,
      'kirmizi' => l10n.hatRenkKirmizi,
      'mor' => l10n.hatRenkMor,
      _ => l10n.hatRenkMavi,
    };

/// (P253 A1) Hatirlatma ekle / duzenle / sil (merkez pencere).
/// Donus `true`: bir sey degisti, cagiran listeyi tazeler.
class HatirlatmaFormu extends ConsumerStatefulWidget {
  const HatirlatmaFormu({super.key, this.mevcut});

  final Hatirlatma? mevcut;

  @override
  ConsumerState<HatirlatmaFormu> createState() => _HatirlatmaFormuState();
}

class _HatirlatmaFormuState extends ConsumerState<HatirlatmaFormu> {
  late final _baslik = TextEditingController(text: widget.mevcut?.baslik ?? '');
  late final _aciklama = TextEditingController(text: widget.mevcut?.aciklama ?? '');
  late DateTime _baslangic = widget.mevcut?.baslangic ?? _yakinSaat();
  late String _tekrar = widget.mevcut?.tekrar ?? 'yok';
  late String _renk = widget.mevcut?.renk ?? 'mavi';
  bool _mesgul = false;
  String? _hata;

  static DateTime _yakinSaat() {
    final s = DateTime.now().add(const Duration(hours: 1));
    return DateTime(s.year, s.month, s.day, s.hour);
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final g = await showDatePicker(
      context: context,
      initialDate: _baslangic,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_baslangic));
    if (!mounted) return;
    setState(() => _baslangic = DateTime(
          g.year, g.month, g.day, s?.hour ?? _baslangic.hour, s?.minute ?? _baslangic.minute));
  }

  String _hataMetni(Object e) {
    final l10n = context.l10n;
    return e is ApiException ? apiHataMetni(l10n, e) : akisHataMetni(l10n, AkisHatasi.beklenmeyen);
  }

  Future<void> _kaydet() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final taslak = HatirlatmaTaslak(
      baslik: _baslik.text.trim(),
      aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
      baslangic: _baslangic,
      bitis: widget.mevcut?.bitis,
      renk: _renk,
      tekrar: _tekrar,
    );
    final api = ref.read(takvimApiProvider);
    try {
      final m = widget.mevcut;
      if (m == null) {
        await api.ekle(taslak);
      } else {
        await api.guncelle(m.id, taslak);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _hata = _hataMetni(e);
        });
      }
    }
  }

  Future<void> _sil() async {
    final m = widget.mevcut!;
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('hat-sil-onay'),
        title: Text(l10n.hatSilBaslik),
        content: Text(l10n.hatSilOnay(m.baslik)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.ortakVazgec)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _mesgul = true);
    try {
      await ref.read(takvimApiProvider).sil(m.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _hata = _hataMetni(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.mevcut == null ? l10n.hatEkle : l10n.hatDuzenle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('hat-baslik'),
            controller: _baslik,
            maxLength: GirdiSiniri.baslik,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.hatBaslik, border: const OutlineInputBorder()),
          ),
          TextField(
            key: const Key('hat-aciklama'),
            controller: _aciklama,
            maxLength: GirdiSiniri.not_,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(labelText: l10n.hatAciklama, border: const OutlineInputBorder()),
          ),
          ListTile(
            key: const Key('hat-zaman'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.hatZaman),
            subtitle: Text(tarihSaatBicimi(_baslangic, dil)),
            onTap: _mesgul ? null : _tarihSec,
          ),
          DropdownButtonFormField<String>(
            key: const Key('hat-tekrar'),
            isExpanded: true,
            initialValue: _tekrar,
            decoration: InputDecoration(labelText: l10n.hatTekrar, border: const OutlineInputBorder()),
            items: [
              for (final t in hatirlatmaTekrarlari)
                DropdownMenuItem(value: t, child: Text(hatTekrarAdi(l10n, t))),
            ],
            onChanged: _mesgul ? null : (v) => setState(() => _tekrar = v ?? 'yok'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('hat-renk'),
            isExpanded: true,
            initialValue: hatirlatmaRenkleri.contains(_renk) ? _renk : 'mavi',
            decoration: InputDecoration(labelText: l10n.hatRenk, border: const OutlineInputBorder()),
            items: [
              for (final r in hatirlatmaRenkleri)
                DropdownMenuItem(value: r, child: Text(hatRenkAdi(l10n, r))),
            ],
            onChanged: _mesgul ? null : (v) => setState(() => _renk = v ?? 'mavi'),
          ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.mevcut != null)
                TextButton(
                  key: const Key('hat-sil'),
                  onPressed: _mesgul ? null : _sil,
                  child: Text(l10n.ortakSil,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const Spacer(),
              TextButton(
                onPressed: _mesgul ? null : () => Navigator.of(context).pop(false),
                child: Text(l10n.ortakVazgec),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('hat-kaydet'),
                onPressed: _mesgul || _baslik.text.trim().isEmpty ? null : _kaydet,
                child: Text(l10n.ortakKaydet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
