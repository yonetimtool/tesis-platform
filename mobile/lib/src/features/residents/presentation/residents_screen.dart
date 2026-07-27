import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/temp_code_dialog.dart';
import '../../../core/validators/password_rule.dart';
import '../data/residents_api.dart';

/// Site Sakinleri — yonetici/admin: sakinleri listeler, yeni tasinani ekler
/// (gecici kod), ayrilani cikarir (pasiflestir). Sakin KENDI kayit olamaz.
class ResidentsScreen extends ConsumerWidget {
  const ResidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(residentsProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.sakinBaslik, context.dilKodu))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.sakinEkle),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          // Sunucu metni varsa o gosterilir (SERVER-LOCALIZED siniri);
          // yoksa yerellestirilmis genel metin.
          message: e is ApiException ? e.message : l10n.sakinListelenemedi,
          onRetry: () => ref.invalidate(residentsProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(residentsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _ResidentTile(member: list[i], ref: ref),
                ),
              ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddResidentSheet(),
    );
    if (created != null) ref.invalidate(residentsProvider);
  }
}

class _ResidentTile extends StatelessWidget {
  const _ResidentTile({required this.member, required this.ref});

  final ResidentMember member;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = member.unitNo?.isNotEmpty == true
        ? l10n.gorevDaireEtiket(member.unitNo!)
        : l10n.sakinDaireYok;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(member.isActive ? Icons.home_outlined : Icons.person_off_outlined),
        ),
        title: Text(member.ad),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!member.isActive)
              Chip(
                label: Text(l10n.devriyePasif),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            PopupMenuButton<String>(
              tooltip: l10n.sakinIslemleri,
              onSelected: (v) {
                if (v == 'edit') _edit(context);
                if (v == 'reset') _resetPassword(context);
                if (v == 'delete') _confirmRemove(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(
                  value: 'reset',
                  child: Text(l10n.sakinParolaSifirla),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.ortakSil)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditResidentSheet(member: member),
    );
    if (changed == true) ref.invalidate(residentsProvider);
  }

  Future<void> _resetPassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Async bosluklardan ONCE yakala.
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sakinParolaSifirlaOnay),
        content: Text(l10n.sakinParolaSifirlaGovde(member.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sakinSifirla),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final code = await ref.read(residentsApiProvider).resetPassword(member.userId);
      if (!context.mounted) return;
      await showTempCodeDialog(
        context,
        code: code,
        message: l10n.sakinYeniKodMesaji(member.ad),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Async bosluklardan ONCE yakala.
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sakinSilOnay),
        content: Text(l10n.sakinSilGovde(member.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final deleted =
          await ref.read(residentsApiProvider).removeResident(member.userId);
      ref.invalidate(residentsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(deleted
            ? l10n.sakinSilindi(member.ad)
            : l10n.sakinPasiflestirildi(member.ad)),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Sakin düzenle alt sayfası — Ad + (opsiyonel) yeni cep telefonu.
class _EditResidentSheet extends ConsumerStatefulWidget {
  const _EditResidentSheet({required this.member});

  final ResidentMember member;

  @override
  ConsumerState<_EditResidentSheet> createState() => _EditResidentSheetState();
}

class _EditResidentSheetState extends ConsumerState<_EditResidentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl =
      TextEditingController(text: widget.member.ad);
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref.read(residentsApiProvider).updateResident(
            widget.member.userId,
            ad: _adCtrl.text.trim(),
            telefon: _phoneCtrl.text.trim(),
          );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sakinGuncellendi)));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
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
            Text(l10n.sakinDuzenleBaslik,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adCtrl,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.ortakAdSoyad,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? l10n.butAdZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.sakinYeniTelefon,
                hintText: l10n.ortakTelefonIpucu,
                helperText: l10n.sakinBosBirakDegismez,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l10n.ortakKaydet),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddResidentSheet extends ConsumerStatefulWidget {
  const _AddResidentSheet();

  @override
  ConsumerState<_AddResidentSheet> createState() => _AddResidentSheetState();
}

class _AddResidentSheetState extends ConsumerState<_AddResidentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _phoneCtrl.dispose();
    _unitCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      final tempCode = await ref.read(residentsApiProvider).addResident(
            ad: _adCtrl.text.trim(),
            telefon: _phoneCtrl.text.trim(),
            unitNo: _unitCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      navigator.pop('ok');
      if (tempCode != null && tempCode.isNotEmpty) {
        await showTempCodeDialog(
          navigator.context,
          code: tempCode,
          message: l10n.sakinEklendiKod,
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.sakinEklendi)));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
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
            Text(l10n.sakinEkle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adCtrl,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.ortakAdSoyad,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? l10n.butAdZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.ortakCepTelefonu,
                hintText: l10n.ortakTelefonIpucu,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                helperText: l10n.sakinGirisAnahtari,
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.ortakTelefonZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.binaDaireNo,
                hintText: l10n.ortakDaireNoIpucu,
                prefixIcon: const Icon(Icons.door_front_door_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim() ?? '').isEmpty
                  ? l10n.sakinDaireNoZorunlu
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              enabled: !_submitting,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.sakinParolaOpsiyonel,
                helperText: l10n.sakinBosBirakKod,
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').isEmpty ? null : passwordError(v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l10n.ortakEkle),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.sakinYok,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(context.l10n.ortakTekrarDene),
            ),
          ],
        ),
      ),
    );
  }
}
