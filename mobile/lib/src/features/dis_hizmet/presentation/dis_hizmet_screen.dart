import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/metin_iste_diyalogu.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/dis_hizmet_api.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/theme/home_tokens.dart';

/// Dis Hizmetler — guvenilir esnaf/hizmet kisileri (cilingir/elektrik/tesisat)
/// + yonetici notu. Yonetici/admin ekler/duzenler/siler + notu yazar; guvenlik
/// ve sakin salt-okuma gorur (arayabilir).
class DisHizmetScreen extends ConsumerWidget {
  const DisHizmetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final canWrite = role == UserRole.admin || role == UserRole.yonetici;
    final async = ref.watch(disHizmetlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(context.l10n.modulDisHizmetler,
            context.dilKodu)),
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.l10n.disKisiEkle),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              // Sunucu metni varsa o (SERVER-LOCALIZED siniri).
              e is ApiException
                  ? apiHataMetni(context.l10n, e)
                  : context.l10n.disListeAlinamadi,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(disHizmetlerProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              _NoteCard(note: data.note, canWrite: canWrite),
              const SizedBox(height: 8),
              if (data.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      canWrite
                          ? context.l10n.disKayitYokYonetim
                          : context.l10n.disKayitYok,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                for (final h in data.items)
                  _HizmetTile(hizmet: h, canWrite: canWrite),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HizmetForm(),
    );
    if (saved == true) ref.invalidate(disHizmetlerProvider);
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.canWrite});

  final String? note;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final has = note != null && note!.trim().isNotEmpty;
    if (!has && !canWrite) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? note! : l10n.disNotEkleyin,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontStyle: has ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            if (canWrite)
              IconButton(
                tooltip: l10n.disNotuDuzenle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editNote(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // (P110) Denetleyici diyalogun kendisine ait (bkz. P109 olcumu).
    final result = await metinIste(
      context,
      baslik: l10n.disBolumNotu,
      onayEtiketi: l10n.ortakKaydet,
      baslangic: note ?? '',
      satirlar: 3,
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(disHizmetApiProvider).setNote(result.isEmpty ? null : result);
      ref.invalidate(disHizmetlerProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.disNotGuncellendi)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}

class _HizmetTile extends ConsumerWidget {
  const _HizmetTile({required this.hizmet, required this.canWrite});

  final DisHizmet hizmet;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = hizmet;
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(h.tur.isNotEmpty ? h.tur[0] : '?')),
        title: Text(h.adSoyad),
        subtitle: Text(
          h.tur +
              (h.aciklama != null && h.aciklama!.isNotEmpty
                  ? '\n${h.aciklama}'
                  : ''),
        ),
        isThreeLine: h.aciklama != null && h.aciklama!.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.disAra,
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => _call(h.telefon),
            ),
            if (canWrite)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _edit(context, ref);
                  if (v == 'delete') _delete(context, ref);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.ortakSil)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HizmetForm(existing: hizmet),
    );
    if (saved == true) ref.invalidate(disHizmetlerProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.disSilOnay),
        content: Text(l10n.disSilGovde(hizmet.adSoyad)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(l10n.ortakVazgec)),
          FilledButton(
              style: yikiciDugmeStili(dctx),
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(l10n.ortakSil)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(disHizmetApiProvider).delete(hizmet.id);
      ref.invalidate(disHizmetlerProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.disSilindi)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}

class _HizmetForm extends ConsumerStatefulWidget {
  const _HizmetForm({this.existing});

  final DisHizmet? existing;

  @override
  ConsumerState<_HizmetForm> createState() => _HizmetFormState();
}

class _HizmetFormState extends ConsumerState<_HizmetForm> {
  final _formKey = GlobalKey<FormState>();
  final _tur = TextEditingController();
  final _ad = TextEditingController();
  final _soyad = TextEditingController();
  final _telefon = TextEditingController();
  final _aciklama = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _tur.text = e.tur;
      _ad.text = e.ad;
      _soyad.text = e.soyad;
      _telefon.text = e.telefon;
      _aciklama.text = e.aciklama ?? '';
    }
  }

  @override
  void dispose() {
    _tur.dispose();
    _ad.dispose();
    _soyad.dispose();
    _telefon.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final aciklama =
        _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim();
    try {
      final api = ref.read(disHizmetApiProvider);
      if (_isEdit) {
        await api.update(
          widget.existing!.id,
          tur: _tur.text.trim(),
          ad: _ad.text.trim(),
          soyad: _soyad.text.trim(),
          telefon: _telefon.text.trim(),
          aciklama: aciklama,
        );
      } else {
        await api.create(
          tur: _tur.text.trim(),
          ad: _ad.text.trim(),
          soyad: _soyad.text.trim(),
          telefon: _telefon.text.trim(),
          aciklama: aciklama,
        );
      }
      if (mounted) navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = apiHataMetni(context.l10n, e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).devriyeKaydedilemedi);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? l10n.disKisiDuzenle : l10n.disYeniKisi,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tur,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.disTur,
                hintText: l10n.disTurIpucu,
                prefixIcon: const Icon(Icons.handyman_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.disTurZorunlu : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ad,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.disAd,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim() ?? '').isEmpty ? l10n.disAdGerekli : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _soyad,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.disSoyad,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim() ?? '').isEmpty ? l10n.disSoyadGerekli : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefon,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.profilTelefon,
                hintText: l10n.ortakTelefonIpucu,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.ortakTelefonZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aciklama,
              enabled: !_busy,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.gorevAciklamaOpsiyonel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(_isEdit ? l10n.ortakGuncelle : l10n.ortakEkle),
            ),
          ],
        ),
      ),
    );
  }
}
