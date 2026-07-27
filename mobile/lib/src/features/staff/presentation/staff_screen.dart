import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/temp_code_dialog.dart';
import '../../../core/validators/password_rule.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/staff_api.dart';
import '../../../core/error/akis_hatasi.dart';

/// Saha Personeli (Ozellik 3) — yonetici/admin: guvenlik + tesis gorevlisi
/// hesaplarini listeler ve ekler. yonetici backend'de YALNIZ saha personeli
/// acabilir; parola bossa donen gecici kod gosterilir.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(fieldStaffProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulPersonel, context.dilKodu)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.personelEkle),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          // Sunucu metni varsa o gosterilir (SERVER-LOCALIZED siniri).
          message: e is ApiException ? apiHataMetni(l10n, e) : l10n.personelListelenemedi,
          onRetry: () => ref.invalidate(fieldStaffProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(fieldStaffProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _StaffTile(member: list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddStaffSheet(),
    );
    if (created != null) {
      ref.invalidate(fieldStaffProvider);
    }
  }
}

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final roleLabel = rolAdi(l10n, UserRole.fromClaim(member.role));
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: member.avatarUrl != null
              ? NetworkImage(member.avatarUrl!)
              : null,
          child: member.avatarUrl == null
              ? Icon(
                  member.role == 'security'
                      ? Icons.shield_outlined
                      : Icons.cleaning_services_outlined,
                )
              : null,
        ),
        title: Text(member.ad),
        subtitle: Text(roleLabel),
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
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref);
                if (v == 'reset') _reset(context, ref);
                if (v == 'toggle') _toggle(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(
                  value: 'reset',
                  child: Text(l10n.sakinParolaSifirla),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(member.isActive
                      ? l10n.personelPasiflestir
                      : l10n.personelAktiflestir),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddStaffSheet(existing: member),
    );
    if (saved != null) ref.invalidate(fieldStaffProvider);
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    // Async bosluklardan ONCE yakala.
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.sakinParolaSifirlaOnay),
        content: Text(l10n.personelSifirlaGovde(member.ad)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(l10n.ortakVazgec)),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(l10n.sakinSifirla)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ctx = context;
    try {
      final code = await ref.read(staffApiProvider).resetPassword(member.id);
      if (!ctx.mounted) return;
      await showTempCodeDialog(
        ctx,
        code: code,
        message: l10n.personelYeniKodMesaji,
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final next = !member.isActive;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(staffApiProvider).setActive(member.id, next);
      ref.invalidate(fieldStaffProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(next
              ? l10n.personelAktiflestirildi
              : l10n.personelPasiflestirildi)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet({this.existing});

  /// null → yeni personel; dolu → o personeli DUZENLE (ad/rol; telefon
  /// opsiyonel — bos ise degismez). Parola alani duzenlemede yok (ayri
  /// "Parola sıfırla" akisi var).
  final StaffMember? existing;

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'security';
  bool _submitting = false;

  // Profil fotografi (P3) — yonetici saha personeli fotosunu yukler.
  Uint8List? _onizleme; // yeni secilen foto (memory onizleme)
  String? _fotoKey; // presign sonrasi yuklendi
  String? _mevcutUrl; // duzenlemede mevcut avatar (network onizleme)
  bool _fotoYukleniyor = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _adCtrl.text = e.ad;
      _role = e.role;
      _mevcutUrl = e.avatarUrl;
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _fotoSec(ImageSource source) async {
    if (_fotoYukleniyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;
    setState(() => _fotoYukleniyor = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: 800,
            imageQuality: 80,
          );
      if (file == null) {
        if (mounted) setState(() => _fotoYukleniyor = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final api = ref.read(staffApiProvider);
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(contentType: contentType);
      await api.uploadPhoto(
          ticket: ticket, bytes: bytes, contentType: contentType);
      if (!mounted) return;
      setState(() {
        _onizleme = bytes;
        _fotoKey = ticket.fotoKey;
        _fotoYukleniyor = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _fotoYukleniyor = false);
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _fotoYukleniyor = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gorevFotoAlinamadi('$e'))),
      );
    }
  }

  void _fotoSecMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheetContext.l10n.gorevKamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _fotoSec(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheetContext.l10n.ortakGaleri),
              onTap: () {
                Navigator.pop(sheetContext);
                _fotoSec(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _phoneCtrl.dispose();
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
      final api = ref.read(staffApiProvider);
      if (_isEdit) {
        await api.updateStaff(
              widget.existing!.id,
              ad: _adCtrl.text.trim(),
              role: _role,
              telefon: _phoneCtrl.text.trim(),
            );
        // Yeni foto secildiyse ata (yalniz yonetici; sunucu zorlar).
        if (_fotoKey != null) {
          await api.setStaffAvatar(widget.existing!.id, _fotoKey);
        }
        if (!mounted) return;
        navigator.pop('ok');
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.personelGuncellendi)),
        );
        return;
      }
      final created = await api.addStaff(
            ad: _adCtrl.text.trim(),
            telefon: _phoneCtrl.text.trim(),
            role: _role,
            password: _passwordCtrl.text,
          );
      // Personel olustuktan sonra foto secildiyse avatarini ata.
      if (_fotoKey != null) {
        await api.setStaffAvatar(created.id, _fotoKey);
      }
      final tempCode = created.tempCode;
      if (!mounted) return;
      navigator.pop('ok');
      if (tempCode != null && tempCode.isNotEmpty) {
        await showTempCodeDialog(
          navigator.context,
          code: tempCode,
          message: l10n.personelEklendiKod,
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.personelEklendi)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
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
            Text(_isEdit ? l10n.personelDuzenle : l10n.personelEkle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Profil fotografi (P3) — yonetici saha personeli fotosunu yukler.
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _onizleme != null
                      ? MemoryImage(_onizleme!)
                      : (_mevcutUrl != null
                          ? NetworkImage(_mevcutUrl!) as ImageProvider
                          : null),
                  child: (_onizleme == null && _mevcutUrl == null)
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _fotoYukleniyor || _submitting ? null : _fotoSecMenu,
                  icon: _fotoYukleniyor
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(l10n.personelFoto),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              // Rol adlari TEK KAYNAKTAN (rolAdi) — segment etiketi de.
              segments: [
                ButtonSegment(
                    value: 'security',
                    label: Text(rolAdi(l10n, UserRole.security)),
                    icon: const Icon(Icons.shield_outlined)),
                ButtonSegment(
                    value: 'tesis_gorevlisi',
                    label: Text(rolAdi(l10n, UserRole.tesisGorevlisi)),
                    icon: const Icon(Icons.cleaning_services_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _role = s.first),
            ),
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
                labelText: _isEdit
                    ? l10n.personelTelefonOpsiyonel
                    : l10n.ortakCepTelefonu,
                hintText: l10n.ortakTelefonIpucu,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                helperText: _isEdit
                    ? l10n.personelBosBirakDegismezNokta
                    : l10n.sakinGirisAnahtari,
              ),
              // Duzenlemede telefon opsiyonel (bos = degismez); eklemede zorunlu.
              validator: (v) => _isEdit || (v?.trim() ?? '').isNotEmpty
                  ? null
                  : l10n.ortakTelefonZorunlu,
            ),
            const SizedBox(height: 12),
            // Parola alani YALNIZ eklemede; duzenlemede ayri "Parola sıfırla".
            if (!_isEdit) ...[
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
                validator: (v) =>
                    (v ?? '').isEmpty ? null : parolaHataMetni(l10n, v),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _submitting
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

/// image_picker mimeType vermezse uzantidan tahmin (announcements ile ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
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
            const Icon(Icons.groups_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.personelYok,
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
