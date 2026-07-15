import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/text/tr_upper.dart';
import '../../../core/error/api_exception.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev foto akisiyla
// ayni saglayici (testlerde tek noktadan override edilir).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/announcement_api.dart';
import '../domain/announcement_models.dart';
import 'announcements_controller.dart';

/// "Duyurular" — tum roller okur; admin/yonetici olusturur/duzenler/siler
/// (FAB + kart menusu yalniz onlarda gorunur; gercek yetki backend'de).
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementsControllerProvider);
    final controller = ref.read(announcementsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(trUpper('Duyurular')),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Yeni duyuru'),
              onPressed: () => _openForm(context, ref),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state, onEdit: (a) => _openForm(context, ref, edit: a)),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Announcement? edit,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AnnouncementForm(announcement: edit),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            edit == null ? 'Duyuru yayınlandı ✓' : 'Duyuru güncellendi ✓',
          ),
        ),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.onEdit});

  final AnnouncementsState state;
  final void Function(Announcement) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(child: Text('Henüz duyuru yok.')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _AnnouncementCard(
        announcement: state.items[i],
        canManage: state.canManage,
        onEdit: onEdit,
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.onEdit,
  });

  final Announcement announcement;
  final bool canManage;
  final void Function(Announcement) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.baslik,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'İşlemler',
                    onSelected: (v) async {
                      if (v == 'edit') onEdit(a);
                      if (v == 'delete') await _confirmDelete(context, ref, a);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.govde),
            if (a.fotoUrl != null) ...[
              const SizedBox(height: 8),
              _AnnouncementPhoto(url: a.fotoUrl!),
            ],
            const SizedBox(height: 8),
            Text(
              '${a.olusturanAd ?? 'Yönetim'} · ${_fmtDateTime(a.createdAt.toLocal())}'
              '${a.duzenlendi ? ' · düzenlendi' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Announcement a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyuru silinsin mi?'),
        content: Text(a.baslik),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(announcementsControllerProvider.notifier).delete(a.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duyuru silindi ✓')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

/// Duyuru gorseli: kartta onizleme; dokununca tam ekran (InteractiveViewer).
/// URL kisa omurlu presigned GET — yuklenemezse sessizce kirik-gorsel satiri.
class _AnnouncementPhoto extends StatelessWidget {
  const _AnnouncementPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, _, _) => Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Row(
              children: [
                Icon(Icons.broken_image_outlined, size: 20),
                SizedBox(width: 8),
                Text('Görsel yüklenemedi'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const Text(
                  'Görsel yüklenemedi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Olustur/duzenle formu (bottom sheet). Sunucu sinirlari istemcide de
/// uygulanir: baslik <= 200, govde <= 5000, bos deger gonderilmez.
/// YENI duyuruda opsiyonel gorsel eklenebilir (cek/sec → presign → PUT →
/// foto_key; gorev foto akisiyla ayni desen). Duzenlemede gorsel alani yok —
/// mevcut gorsel korunur (foto_key PATCH'e yazilmaz).
class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({this.announcement});

  /// null → yeni duyuru; dolu → duzenleme.
  final Announcement? announcement;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baslikCtrl;
  late final TextEditingController _govdeCtrl;
  bool _saving = false;
  String? _error;

  /// Secilen fotonun cihaz yolu (onizleme). [_fotoKey] dolu ise yukleme
  /// tamamlanmistir; secili olup yuklenmemisse gonderim beklemeli.
  String? _photoPath;
  bool _photoBusy = false;
  String? _photoError;
  String? _fotoKey;

  bool get _fotoBekliyor => _photoPath != null && _fotoKey == null;

  @override
  void initState() {
    super.initState();
    _baslikCtrl = TextEditingController(text: widget.announcement?.baslik);
    _govdeCtrl = TextEditingController(text: widget.announcement?.govde);
  }

  @override
  void dispose() {
    _baslikCtrl.dispose();
    _govdeCtrl.dispose();
    super.dispose();
  }

  /// Foto cek/sec → presign → PUT → foto_key (gorev akisinin aynisi).
  /// Foto OPSIYONEL — vazgecilirse/kaldirilirsa duyuru foto'suz gider.
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Duyuru gorseli icin cozunurluk/kalite dusurulur (yukleme boyutu).
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (!mounted) return;
      if (file == null) {
        // Kullanici vazgecti — mevcut secim korunur.
        setState(() => _photoBusy = false);
        return;
      }
      setState(() {
        _photoPath = file.path;
        // Eski yukleme gecersiz: yeni foto secildi.
        _fotoKey = null;
      });
      await _uploadPhoto(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = 'Fotoğraf alınamadı: $e';
      });
    }
  }

  /// Secili fotoyu (yeniden) yukler — presign URL suresi dolmus ya da
  /// yukleme yarim kalmis olabilir.
  Future<void> _retryUpload() async {
    final path = _photoPath;
    if (path == null || _photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    await _uploadPhoto(XFile(path));
  }

  Future<void> _uploadPhoto(XFile file) async {
    final api = ref.read(announcementApiProvider);
    try {
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      final bytes = await file.readAsBytes();
      await api.uploadPhoto(
        ticket: ticket,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _fotoKey = ticket.fotoKey;
        _photoError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = e.kind == ApiErrorKind.network
            ? 'Fotoğraf yüklemek için internet bağlantısı gerekli '
                '(yükleme adresi kısa ömürlü). Bağlantı gelince '
                '"Tekrar yükle" ile deneyin.'
            : e.message;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoError = null;
      _fotoKey = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fotoBekliyor) {
      setState(() {
        _error = 'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin, '
            '"Tekrar yükle"yi deneyin veya fotoyu kaldırın.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = AnnouncementDraft(
      baslik: _baslikCtrl.text.trim(),
      govde: _govdeCtrl.text.trim(),
      // Duzenlemede foto alani yok; null → JSON'a yazilmaz, mevcut korunur.
      fotoKey: _fotoKey,
    );
    final controller = ref.read(announcementsControllerProvider.notifier);
    try {
      if (widget.announcement == null) {
        await controller.create(draft);
      } else {
        await controller.update(widget.announcement!.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.announcement != null;
    return Padding(
      // Klavye acildiginda formun gorunur kalmasi icin.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        // Gorsel onizleme + klavye ile icerik uzayabilir — tasma yerine kaydir.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Duyuru düzenle' : 'Yeni duyuru',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baslikCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Başlık zorunludur' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _govdeCtrl,
              maxLength: 5000,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Duyuru metni',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Duyuru metni zorunludur'
                  : null,
            ),
            // Gorsel yalniz YENI duyuruda eklenir (duzenlemede mevcut korunur).
            if (!editing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _fotoKey != null
                        ? Icons.check_circle
                        : Icons.image_outlined,
                    color: _fotoKey != null ? Colors.green : null,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('Görsel (opsiyonel)'),
                ],
              ),
              if (_photoPath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_photoPath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_photoBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
              if (_photoError != null) ...[
                const SizedBox(height: 4),
                Text(_photoError!, style: const TextStyle(color: Colors.red)),
              ],
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _photoBusy || _saving
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoPath == null ? 'Kamera' : 'Yeniden çek'),
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy || _saving
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden seç'),
                  ),
                  if (_photoPath != null && _fotoKey == null)
                    TextButton.icon(
                      onPressed: _photoBusy || _saving ? null : _retryUpload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar yükle'),
                    ),
                  if (_photoPath != null)
                    TextButton.icon(
                      onPressed: _photoBusy || _saving ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Kaldır'),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: Text(
                  _saving
                      ? 'Gönderiliyor...'
                      : editing
                          ? 'Kaydet'
                          : 'Yayınla',
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// image_picker mimeType vermezse uzantidan tahmin (gorev akisiyla ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
