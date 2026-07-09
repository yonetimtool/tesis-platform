import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev/duyuru foto
// akisiyla ayni saglayici (testlerde tek noktadan override edilir).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/complaint_api.dart';
import '../domain/complaint_models.dart';
import 'complaints_controller.dart';

/// "Sikayet / Oneri" — sakin<->yonetim kanali (auth.md §4 UX aynasi):
///   * resident: KENDI talepleri + "Yeni talep" FAB'i; yaniti okur.
///   * admin/yonetici: tenant'taki TUM talepler; detayda durum+yanit yazar.
///   * security/tesis_gorevlisi bu ekrana hic gelmez (menude yok; backend 403).
class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(complaintsControllerProvider);
    final controller = ref.read(complaintsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sikayet / Oneri'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canCreate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Yeni talep'),
              onPressed: () => _openForm(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComplaintForm(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talebiniz iletildi ✓')),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final ComplaintsState state;

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
        children: [
          Center(
            child: Text(
              state.canCreate
                  ? 'Henuz talebiniz yok. "Yeni talep" ile '
                      'sikayet/onerinizi iletebilirsiniz.'
                  : 'Henuz talep yok.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _ComplaintCard(
        complaint: state.items[i],
        canRespond: state.canRespond,
      ),
    );
  }
}

/// Durum rozeti — renk kodu: acik=mavi, inceleniyor=turuncu, cozuldu=yesil.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final ComplaintDurum durum;

  Color get _color => switch (durum) {
        ComplaintDurum.acik => Colors.blue,
        ComplaintDurum.inceleniyor => Colors.orange,
        ComplaintDurum.cozuldu => Colors.green,
        ComplaintDurum.unknown => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        durum.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ComplaintCard extends ConsumerWidget {
  const _ComplaintCard({required this.complaint, required this.canRespond});

  final Complaint complaint;
  final bool canRespond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = complaint;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.baslik,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _DurumChip(durum: c.durum),
                ],
              ),
              const SizedBox(height: 4),
              Text(c.mesaj, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (c.yanitli) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Yonetim yaniti: ${c.yoneticiYaniti}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (c.fotoUrl != null) ...[
                    const Icon(Icons.image_outlined, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      // Yonetim gorunumunde kim actigi onemli; sakin zaten
                      // yalniz kendi taleplerini gorur.
                      '${canRespond ? '${c.acanAd ?? 'Sakin'} · ' : ''}'
                      '${_fmtDateTime(c.createdAt.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComplaintDetail(complaint: complaint, canRespond: canRespond),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanit kaydedildi ✓')),
      );
    }
  }
}

/// Detay + (yonetimde) yanit formu. Sakin icin salt okunur: mesajin tamami,
/// gorsel ve yonetim yaniti.
class _ComplaintDetail extends ConsumerStatefulWidget {
  const _ComplaintDetail({required this.complaint, required this.canRespond});

  final Complaint complaint;
  final bool canRespond;

  @override
  ConsumerState<_ComplaintDetail> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends ConsumerState<_ComplaintDetail> {
  late ComplaintDurum _durum;
  late final TextEditingController _yanitCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _durum = widget.complaint.durum == ComplaintDurum.unknown
        ? ComplaintDurum.acik
        : widget.complaint.durum;
    _yanitCtrl = TextEditingController(text: widget.complaint.yoneticiYaniti);
  }

  @override
  void dispose() {
    _yanitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = widget.complaint;
    final yanit = _yanitCtrl.text.trim();
    final draft = ComplaintReplyDraft(
      durum: _durum == c.durum ? null : _durum,
      // Yanit degismediyse tekrar gonderilmez (damga korunur).
      yoneticiYaniti:
          yanit.isEmpty || yanit == c.yoneticiYaniti ? null : yanit,
    );
    if (draft.bos) {
      setState(() => _error = 'Degisiklik yok: durum secin veya yanit yazin.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(complaintsControllerProvider.notifier)
          .reply(c.id, draft);
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
          _error = 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.baslik,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _DurumChip(durum: c.durum),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.canRespond ? '${c.acanAd ?? 'Sakin'} · ' : ''}'
              '${_fmtDateTime(c.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(c.mesaj),
            if (c.fotoUrl != null) ...[
              const SizedBox(height: 12),
              _ComplaintPhoto(url: c.fotoUrl!),
            ],
            const SizedBox(height: 12),
            if (c.yanitli && !widget.canRespond) ...[
              // Sakin gorunumu: yanit salt okunur blok.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yonetim yaniti'
                      '${c.yanitZamani != null ? ' · ${_fmtDateTime(c.yanitZamani!.toLocal())}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(c.yoneticiYaniti!),
                  ],
                ),
              ),
            ],
            if (!c.yanitli && !widget.canRespond)
              Text(
                'Yonetim yaniti bekleniyor.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (widget.canRespond) ...[
              const Divider(height: 24),
              Text('Durum', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              SegmentedButton<ComplaintDurum>(
                segments: const [
                  ButtonSegment(
                    value: ComplaintDurum.acik,
                    label: Text('Acik'),
                  ),
                  ButtonSegment(
                    value: ComplaintDurum.inceleniyor,
                    label: Text('Inceleniyor'),
                  ),
                  ButtonSegment(
                    value: ComplaintDurum.cozuldu,
                    label: Text('Cozuldu'),
                  ),
                ],
                selected: {_durum},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _durum = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _yanitCtrl,
                maxLength: 5000,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Yonetim yaniti',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.reply),
                  label: Text(_saving ? 'Kaydediliyor...' : 'Yaniti kaydet'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Talep gorseli: onizleme; dokununca tam ekran (InteractiveViewer).
/// URL kisa omurlu presigned GET — yuklenemezse kirik-gorsel satiri.
class _ComplaintPhoto extends StatelessWidget {
  const _ComplaintPhoto({required this.url});

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
                Text('Gorsel yuklenemedi'),
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
                  'Gorsel yuklenemedi',
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

/// Yeni talep formu (bottom sheet, yalniz resident). Sunucu sinirlari
/// istemcide de uygulanir: baslik <= 200, mesaj <= 5000, bos deger
/// gonderilmez. Opsiyonel gorsel: cek/sec → presign → PUT → foto_key
/// (gorev/duyuru foto akisiyla ayni desen).
class _ComplaintForm extends ConsumerStatefulWidget {
  const _ComplaintForm();

  @override
  ConsumerState<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends ConsumerState<_ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final _baslikCtrl = TextEditingController();
  final _mesajCtrl = TextEditingController();
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
  void dispose() {
    _baslikCtrl.dispose();
    _mesajCtrl.dispose();
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
            // Talep gorseli icin cozunurluk/kalite dusurulur (yukleme boyutu).
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
        _photoError = 'Fotograf alinamadi: $e';
      });
    }
  }

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
    final api = ref.read(complaintApiProvider);
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
            ? 'Fotograf yuklemek icin internet baglantisi gerekli '
                '(yukleme adresi kisa omurlu). Baglanti gelince '
                '"Tekrar yukle" ile deneyin.'
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
        _error = 'Fotograf henuz yuklenmedi. Yuklemenin bitmesini bekleyin, '
            '"Tekrar yukle"yi deneyin veya fotoyu kaldirin.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = ComplaintDraft(
      baslik: _baslikCtrl.text.trim(),
      mesaj: _mesajCtrl.text.trim(),
      fotoKey: _fotoKey,
    );
    try {
      await ref.read(complaintsControllerProvider.notifier).create(draft);
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
          _error = 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Yeni sikayet / oneri',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baslikCtrl,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Baslik',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Baslik zorunludur' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mesajCtrl,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Mesajiniz',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Mesaj zorunludur'
                    : null,
              ),
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
                  const Text('Gorsel (opsiyonel)'),
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
                    label: Text(_photoPath == null ? 'Foto cek' : 'Yeniden cek'),
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy || _saving
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden sec'),
                  ),
                  if (_photoPath != null && _fotoKey == null)
                    TextButton.icon(
                      onPressed: _photoBusy || _saving ? null : _retryUpload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar yukle'),
                    ),
                  if (_photoPath != null)
                    TextButton.icon(
                      onPressed: _photoBusy || _saving ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Kaldir'),
                    ),
                ],
              ),
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
                      : const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'Gonderiliyor...' : 'Gonder'),
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
