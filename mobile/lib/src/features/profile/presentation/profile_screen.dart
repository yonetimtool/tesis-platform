import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/validators/password_rule.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/avatar_api.dart';
import '../data/profile_api.dart';
import '../domain/profile.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/widgets/bas_harf_avatar.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/telefon_alani.dart';

/// Self-servis profil ekrani — kullanici KENDI parolasini ve telefon/arama
/// rizasini gunceller (contracts/auth.md self-servis profil). Sag-ust profil
/// ikonundan acilir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.kabukProfil, context.dilKodu)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          // Sunucu metni varsa o gosterilir (SERVER-LOCALIZED siniri).
          message: e is ApiException ? apiHataMetni(l10n, e) : l10n.profilYuklenemedi,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(profile: profile),
            const SizedBox(height: 16),
            // Self-servis profil fotografi YALNIZ yonetici + site sakini
            // (spec P3). admin/guvenlik/tesis gorevlisi'nde gizli — saha
            // personeli fotosunu yonetici StaffScreen'den yonetir.
            if (UserRole.fromClaim(profile.role) == UserRole.yonetici ||
                UserRole.fromClaim(profile.role) == UserRole.resident) ...[
              _AvatarCard(ad: profile.ad),
              const SizedBox(height: 16),
            ],
            const _PasswordCard(),
            const SizedBox(height: 16),
            _ContactCard(
              initialTelefon: profile.telefon ?? '',
              initialAranabilir: profile.aranabilir,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final roleLabel = rolAdi(l10n, UserRole.fromClaim(profile.role));
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.person_outline,
              size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.ad,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(roleLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                profile.telefon?.isNotEmpty == true
                    ? profile.telefon!
                    : l10n.profilNumaraYok,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Profil fotografi karti (WP-D) — personel rolleri kendi avatarini yukler/
/// kaldirir. Onizleme [myAvatarUrlProvider]'dan; yukleme announcements'daki
/// presign PUT deseniyle. Hata SnackBar; ekran asla dusmez.
class _AvatarCard extends ConsumerStatefulWidget {
  const _AvatarCard({required this.ad});

  /// Bas harfleri cizmek icin — fotograf yokken kimlik gostergesi.
  final String ad;

  @override
  ConsumerState<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends ConsumerState<_AvatarCard> {
  bool _busy = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _sec(ImageSource source) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;
    setState(() => _busy = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: 800, // profil fotosu — kucuk yeter
            imageQuality: 80,
          );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return; // kullanici vazgecti
      }
      final api = ref.read(avatarApiProvider);
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(contentType: contentType);
      await api.uploadPhoto(
        ticket: ticket,
        bytes: await file.readAsBytes(),
        contentType: contentType,
      );
      await api.setAvatar(ticket.fotoKey);
      if (!mounted) return;
      ref.invalidate(myAvatarUrlProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilFotoGuncellendi)),
      );
    } on ApiException catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.gorevFotoAlinamadi('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _kaldir() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;
    setState(() => _busy = true);
    try {
      await ref.read(avatarApiProvider).setAvatar(null);
      if (!mounted) return;
      ref.invalidate(myAvatarUrlProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilFotoKaldirildi)),
      );
    } on ApiException catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _kaynakSec() {
    merkezSayfaAc<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheetContext.l10n.gorevKamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _sec(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheetContext.l10n.ortakGaleri),
              onTap: () {
                Navigator.pop(sheetContext);
                _sec(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // (P212 §2) UC DURUM AYRI: fotograf VAR / fotograf YOK / OKUNAMADI.
    // Ucunu de `null`a indirmek, hatayi "fotograf yok" gibi gosteriyordu.
    final durum = ref.watch(myAvatarUrlProvider);
    final url = durum.value;
    final okunamadi = durum.hasError;
    final ad = widget.ad;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // (P212 §2) FOTOGRAF YOKSA BAS HARFLER — genel silüet DEGIL.
            BasHarfAvatar(ad: ad, url: url, cap: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.profilFotoBaslik,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _kaynakSec,
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(l10n.profilFotoSec),
                      ),
                      if (url != null)
                        TextButton(
                          key: const Key('profil-foto-kaldir'),
                          onPressed: _busy ? null : _kaldir,
                          child: Text(l10n.gorevKaldir),
                        ),
                      // OKUNAMADIYSA SESSIZ KALINMAZ: "fotograf yok"
                      // ile "okuyamadim" ayni sey degil; ikincisinde
                      // kullaniciya tekrar deneme yolu verilir.
                      if (okunamadi) ...[
                        Text(
                          l10n.profilFotoOkunamadi,
                          key: const Key('profil-foto-hata'),
                          style: TextStyle(color: scheme.error, fontSize: 12),
                        ),
                        TextButton(
                          key: const Key('profil-foto-tekrar'),
                          onPressed: _busy
                              ? null
                              : () => ref.invalidate(myAvatarUrlProvider),
                          child: Text(l10n.ortakTekrarDene),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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

/// Parola degistirme karti: mevcut / yeni / yeni (tekrar). Client-side eslesme
/// + min 8; backend mevcut parolayi dogrular (hatali → 400).
class _PasswordCard extends ConsumerStatefulWidget {
  const _PasswordCard();

  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref.read(profileApiProvider).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilParolaGuncellendi)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profilParolaDegistir,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.profilMevcutParola,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    // EKRAN OKUYUCU etiketi (tur 29) — duruma gore degisir.
                    tooltip: _obscure
                        ? l10n.ortakParolayiGoster
                        : l10n.ortakParolayiGizle,
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? l10n.profilMevcutParolaZorunlu
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.ortakYeniParola,
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? l10n.ortakYeniParolaZorunlu
                    : parolaHataMetni(l10n, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.ortakYeniParolaTekrar,
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '') != _newCtrl.text
                    ? l10n.ortakParolalarEslesmiyor
                    : null,
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
                    : Text(l10n.profilParolaGuncelle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iletisim karti: telefon + "Aranabilir" (aranmaya riza). En az bir alan
/// degisince kaydedilir; kayit sonrasi profil tazelenir.
class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({
    required this.initialTelefon,
    required this.initialAranabilir,
  });

  final String initialTelefon;
  final bool initialAranabilir;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  late final TextEditingController _telefonCtrl =
      TextEditingController(text: widget.initialTelefon);
  late bool _aranabilir = widget.initialAranabilir;
  bool _submitting = false;

  @override
  void dispose() {
    _telefonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref.read(profileApiProvider).updateContact(
            telefon: telefonNormalle(_telefonCtrl.text),
            aranabilir: _aranabilir,
          );
      if (!mounted) return;
      ref.invalidate(profileProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilIletisimGuncellendi)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.etiketIletisim,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              // (P123) TEK bicimlendirici: gruplar, rakam disini
              // yutar, uzunlugu SERT sinirlar, yapistirmayi cozer.
              inputFormatters: const [TelefonBicimlendirici()],
              decoration: InputDecoration(
                labelText: l10n.profilTelefon,
                hintText: l10n.profilTelefonIpucu,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              value: _aranabilir,
              onChanged:
                  _submitting ? null : (v) => setState(() => _aranabilir = v),
              title: Text(l10n.profilAranabilir),
              subtitle: Text(l10n.profilAranabilirAlt),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
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
                  : Text(l10n.profilIletisimKaydet),
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
