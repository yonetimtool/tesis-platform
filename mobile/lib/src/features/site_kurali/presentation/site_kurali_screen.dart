import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev/duyuru/talep/
// kargo foto akisiyla ayni saglayici (testlerde tek noktadan override).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/site_kurali_api.dart';
import '../domain/site_kurali_models.dart';
import 'site_kurali_controller.dart';

/// "Site Kurallari" — blog-tarzi kural listesi (auth.md §4, UX aynasi):
///   * herkes: sira'ya gore sirali liste (baslik + metin + varsa gorsel) +
///     ustte ARAMA CUBUGU (basliga gore anlik suzer).
///   * yonetim (admin/yonetici): "Yeni kural" FAB'i + detayda duzenle/sil;
///     digerleri salt okur (yonetim butonlari gorunmez).
class SiteKuraliScreen extends ConsumerWidget {
  const SiteKuraliScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(siteKuraliControllerProvider);
    final controller = ref.read(siteKuraliControllerProvider.notifier);
    final kurallar = state.suzulmus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Kuralları'),
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
              icon: const Icon(Icons.post_add_outlined),
              label: const Text('Yeni kural'),
              onPressed: () => _openForm(context),
            )
          : null,
      body: Column(
        children: [
          // ARAMA CUBUGU: basliga gore ANLIK suzer (istemci tarafi;
          // sunucuda ?q= ILIKE ayrica mevcut).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: controller.search,
              decoration: InputDecoration(
                hintText: 'Başlıkta ara (örn. havuz)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(state: state, items: kurallar),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openForm(BuildContext context,
      {SiteKurali? mevcut}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _KuralForm(mevcut: mevcut),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(mevcut == null ? 'Kural eklendi ✓' : 'Kural güncellendi ✓'),
        ),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.items});

  final SiteKuraliState state;

  /// Arama suzgecinden gecen kurallar.
  final List<SiteKurali> items;

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
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              state.sorgu.trim().isNotEmpty
                  ? 'Aramayla eşleşen kural yok.'
                  : state.canManage
                      ? 'Henüz kural yok. "Yeni kural" ile ekleyin.'
                      : 'Henüz kural yayınlanmamış.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: items.length,
      itemBuilder: (context, i) => _KuralCard(
        kural: items[i],
        canManage: state.canManage,
      ),
    );
  }
}

class _KuralCard extends ConsumerWidget {
  const _KuralCard({required this.kural, required this.canManage});

  final SiteKurali kural;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = kural;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, k, canManage: canManage),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_outlined, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      k.baslik,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (k.fotoUrl != null)
                    const Icon(Icons.image_outlined, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(k.icerik, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detay alt sayfasi — tam metin + gorsel; yonetimde duzenle/sil.
void _showDetail(BuildContext context, SiteKurali k,
    {required bool canManage}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      k.baslik,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(k.icerik),
              if (k.fotoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    k.fotoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                    errorBuilder: (_, _, _) => Container(
                      height: 48,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
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
              ],
              if (canManage) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Düzenle'),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _KuralForm(mevcut: k),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DeleteButton(
                        kural: k,
                        onDeleted: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sil butonu — onay dialogu ister (HARD DELETE; geri alinamaz).
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.kural, required this.onDeleted});

  final SiteKurali kural;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      icon: const Icon(Icons.delete_outline),
      label: const Text('Sil'),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final onay = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Kural silinsin mi?'),
            content: Text('"${kural.baslik}" kalıcı olarak silinecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dctx).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        if (onay != true) return;
        try {
          await ref
              .read(siteKuraliControllerProvider.notifier)
              .delete(kural.id);
          messenger.showSnackBar(
            const SnackBar(content: Text('Kural silindi ✓')),
          );
          onDeleted();
        } on ApiException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }
}

/// Kural ekle/duzenle formu (yonetim): baslik + metin + sira + opsiyonel
/// gorsel. Foto akisi complaints/kargo formuyla AYNI: cek/sec → presign →
/// PUT → foto_key (yeni upload yolu yok).
class _KuralForm extends ConsumerStatefulWidget {
  const _KuralForm({this.mevcut});

  /// Dolu ise DUZENLEME modu (alanlar on-dolu gelir).
  final SiteKurali? mevcut;

  @override
  ConsumerState<_KuralForm> createState() => _KuralFormState();
}

class _KuralFormState extends ConsumerState<_KuralForm> {
  final _formKey = GlobalKey<FormState>();
  late final _baslik = TextEditingController(text: widget.mevcut?.baslik);
  late final _icerik = TextEditingController(text: widget.mevcut?.icerik);
  late final _sira =
      TextEditingController(text: widget.mevcut?.sira.toString() ?? '0');
  bool _busy = false;
  String? _hata;

  /// Secilen fotonun cihaz yolu (onizleme). [_fotoKey] dolu ise yukleme
  /// tamamlanmistir; secili olup yuklenmemisse gonderim beklemeli.
  String? _photoPath;
  bool _photoBusy = false;
  String? _photoError;
  late String? _fotoKey = widget.mevcut?.fotoKey;

  /// Duzenlemede mevcut gorselin kaldirildigini isaretler (acik null PATCH).
  bool _fotoKaldirildi = false;

  bool get _fotoBekliyor => _photoPath != null && _fotoKey == null;

  @override
  void dispose() {
    _baslik.dispose();
    _icerik.dispose();
    _sira.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Kural gorseli icin cozunurluk/kalite dusurulur (yukleme boyutu).
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
        _fotoKaldirildi = false;
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

  Future<void> _uploadPhoto(XFile file) async {
    final api = ref.read(siteKuraliApiProvider);
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
            ? 'Fotoğraf yüklemek için internet bağlantısı gerekli. '
                'Bağlantı gelince tekrar deneyin.'
            : e.message;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoError = null;
      _fotoKey = null;
      // Duzenlemede mevcut gorsel de kaldirilmis sayilir (acik null PATCH).
      _fotoKaldirildi = widget.mevcut?.fotoKey != null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_fotoBekliyor) {
      setState(() {
        _hata = 'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin '
            'veya fotoyu kaldırın.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _hata = null;
    });
    final draft = SiteKuraliDraft(
      baslik: _baslik.text.trim(),
      icerik: _icerik.text.trim(),
      sira: int.tryParse(_sira.text.trim()) ?? 0,
      fotoKey: _fotoKey,
      fotoKeyKaldir: _fotoKaldirildi,
    );
    try {
      final controller = ref.read(siteKuraliControllerProvider.notifier);
      if (widget.mevcut == null) {
        await controller.create(draft);
      } else {
        await controller.update(widget.mevcut!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hata = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hata = 'Kaydedilemedi. Tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    // Mevcut/yeni gorsel gostergesi: yeni secim onizlenir; duzenlemede
    // secim yoksa mevcut foto_key'in varligi metinle belirtilir.
    final mevcutFotoVar =
        widget.mevcut?.fotoKey != null && !_fotoKaldirildi && _photoPath == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mevcut == null ? 'Yeni kural' : 'Kuralı düzenle',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baslik,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Başlık * (örn. Havuz Saatleri)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _icerik,
                decoration: const InputDecoration(
                  labelText: 'Kural metni *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 10000,
                minLines: 3,
                maxLines: 8,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Kural metni gerekli'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sira,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sıra (küçük önce)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 0)
                      ? 'Sıra 0 veya pozitif tam sayı olmalı'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _fotoKey != null || mevcutFotoVar
                        ? Icons.check_circle
                        : Icons.image_outlined,
                    color: _fotoKey != null || mevcutFotoVar
                        ? Colors.green
                        : null,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(mevcutFotoVar
                      ? 'Mevcut görsel korunuyor'
                      : 'Görsel (opsiyonel)'),
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
                    onPressed: _photoBusy || _busy
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoPath == null ? 'Kamera' : 'Yeniden çek'),
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy || _busy
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden seç'),
                  ),
                  if (_photoPath != null || mevcutFotoVar)
                    TextButton.icon(
                      onPressed: _photoBusy || _busy ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Kaldır'),
                    ),
                ],
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(_hata!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.post_add_outlined),
                  label: Text(widget.mevcut == null ? 'Kuralı ekle' : 'Kaydet'),
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// image_picker mimeType vermezse uzantidan tahmin (mevcut akislarla ayni).
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
