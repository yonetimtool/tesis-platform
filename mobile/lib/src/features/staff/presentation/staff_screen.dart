import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/text/tr_upper.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/ui/temp_code_dialog.dart';
import '../../../core/validators/password_rule.dart';
import '../../auth/domain/user_role.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/staff_api.dart';

/// Saha Personeli (Ozellik 3) — yonetici/admin: guvenlik + tesis gorevlisi
/// hesaplarini listeler ve ekler. yonetici backend'de YALNIZ saha personeli
/// acabilir; parola bossa donen gecici kod gosterilir.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(fieldStaffProvider);
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Saha Personeli'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Personel ekle'),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e is ApiException ? e.message : 'Personel listelenemedi.',
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
    final roleLabel = UserRole.fromClaim(member.role).label;
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
                label: const Text('Pasif'),
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
                const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                const PopupMenuItem(
                    value: 'reset', child: Text('Parola sıfırla')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(member.isActive ? 'Pasifleştir' : 'Aktifleştir'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Parola sıfırlansın mı?'),
        content: Text(
          '${member.ad} için yeni geçici kod üretilecek; eski parola geçersiz olur.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Sıfırla')),
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
        message: 'Yeni geçici kod. Personele iletin; telefon + bu kod ile '
            'girip parolasını belirler.',
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final next = !member.isActive;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(staffApiProvider).setActive(member.id, next);
      ref.invalidate(fieldStaffProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(next ? 'Aktifleştirildi ✓' : 'Pasifleştirildi ✓')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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

  Future<void> _fotoSec(ImageSource source) async {
    if (_fotoYukleniyor) return;
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _fotoYukleniyor = false);
      messenger.showSnackBar(SnackBar(content: Text('Fotoğraf alınamadı: $e')));
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
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _fotoSec(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
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
          const SnackBar(content: Text('Personel güncellendi ✓')),
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
          message: 'Personel eklendi. Bu kodu personele iletin; telefon + bu '
              'kod ile girip parolasını belirler.',
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Personel eklendi ✓')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Personel düzenle' : 'Personel ekle',
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
                  label: const Text('Fotoğraf'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'security',
                    label: Text('Güvenlik'),
                    icon: Icon(Icons.shield_outlined)),
                ButtonSegment(
                    value: 'tesis_gorevlisi',
                    label: Text('Tesis Görevlisi'),
                    icon: Icon(Icons.cleaning_services_outlined)),
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
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? 'Ad zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText:
                    _isEdit ? 'Cep telefonu (opsiyonel)' : 'Cep telefonu',
                hintText: 'örn. 0532 111 22 03',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                helperText: _isEdit
                    ? 'Boş bırakırsanız değişmez.'
                    : 'Giriş anahtarı (global benzersiz).',
              ),
              // Duzenlemede telefon opsiyonel (bos = degismez); eklemede zorunlu.
              validator: (v) => _isEdit || (v?.trim() ?? '').isNotEmpty
                  ? null
                  : 'Telefon zorunludur',
            ),
            const SizedBox(height: 12),
            // Parola alani YALNIZ eklemede; duzenlemede ayri "Parola sıfırla".
            if (!_isEdit) ...[
              TextFormField(
                controller: _passwordCtrl,
                enabled: !_submitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parola (opsiyonel)',
                  helperText: 'Boş bırakırsanız geçici kod üretilir',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').isEmpty ? null : passwordError(v),
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
                  : Text(_isEdit ? 'Güncelle' : 'Ekle'),
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
              'Henüz saha personeli yok.\nSağ alttan ekleyebilirsiniz.',
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
            FilledButton.tonal(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
