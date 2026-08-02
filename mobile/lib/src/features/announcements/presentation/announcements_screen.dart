import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/icerik_ceviri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/ceviri_notu.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev foto akisiyla
// ayni saglayici (testlerde tek noktadan override edilir).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/announcement_api.dart';
import '../domain/announcement_models.dart';
import 'announcements_controller.dart';
import '../../../core/ui/gorsel_cozme.dart';
import '../../../core/ui/merkez_diyalog.dart';

/// "Duyurular" — tum roller okur; admin/yonetici olusturur/duzenler/siler
/// (FAB + kart menusu yalniz onlarda gorunur; gercek yetki backend'de).
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementsControllerProvider);
    final controller = ref.read(announcementsControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulDuyurular, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.campaign_outlined),
              label: Text(l10n.duyuruYeni),
              onPressed: () => _openForm(context, ref),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(
          state: state,
          onEdit: (a) => _openForm(context, ref, edit: a),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Announcement? edit,
  }) async {
    final saved = await merkezSayfaAc<bool>(
      context,
      builder: (_) => _AnnouncementForm(announcement: edit),
    );
    if (saved == true && context.mounted) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            edit == null ? l10n.duyuruYayinlandi : l10n.duyuruGuncellendi,
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
    final l10n = context.l10n;
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    if (hata != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            hata,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(l10n.duyuruYok))],
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

class _AnnouncementCard extends ConsumerStatefulWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.onEdit,
  });

  final Announcement announcement;
  final bool canManage;
  final void Function(Announcement) onEdit;

  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  /// Kullanici "orijinali gör" dedi mi? Kart BASINA tutulur: bir duyurunun
  /// orijinaline bakmak digerlerini etkilemez.
  bool _orijinal = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final canManage = widget.canManage;
    final onEdit = widget.onEdit;
    final l10n = context.l10n;
    final baslik = ceviriMetni(
      a.ceviri,
      'baslik',
      a.baslik,
      orijinalGoster: _orijinal,
    );
    final govde = ceviriMetni(
      a.ceviri,
      'govde',
      a.govde,
      orijinalGoster: _orijinal,
    );
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
                    baslik,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: l10n.ortakIslemler,
                    onSelected: (v) async {
                      if (v == 'edit') onEdit(a);
                      if (v == 'delete') await _confirmDelete(context, ref, a);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.ortakDuzenle),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.ortakSil),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(govde),
            // Ceviri notu METNIN hemen altinda: rozet gorselin ya da meta
            // satirinin arasina girerse hangi metne ait oldugu belirsizlesir.
            CeviriNotu(
              ceviri: a.ceviri,
              orijinalGoster: _orijinal,
              onDegistir: (v) => setState(() => _orijinal = v),
            ),
            if (a.fotoUrl != null) ...[
              const SizedBox(height: 8),
              _AnnouncementPhoto(url: a.fotoUrl!),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.duyuruMeta(
                a.olusturanAd ?? l10n.duyuruYonetim,
                tarihSaatBicimi(a.createdAt, context.dilKodu),
                a.duzenlendi ? l10n.duyuruDuzenlendiEki : '',
              ),
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
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.duyuruSilOnay),
        content: Text(a.baslik),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ortakIptal),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(announcementsControllerProvider.notifier).delete(a.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.duyuruSilindi)));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
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
    // Klavyeyle de acilabilmeli (tur 33) — `InkWell` kendi `Focus`unu kurar.
    // Fotograf ekran okuyucuda ADSIZDI (tur 34): "resim, dugme" diye
    // okunuyordu. Etiket DOKUNULABILIR dugumle birlesmeli —
    // `MergeSemantics` olmadan ayri bir alt dugumde kalir.
    return MergeSemantics(
      child: Semantics(
        label: context.l10n.ortakFotografiBuyut,
        child: InkWell(
          onTap: () => _openFullScreen(context),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              // Etiketsiz gorsel ekran okuyucuda HIC duyurulmaz (tur 34).
              semanticLabel: context.l10n.ortakFotograf,
              height: 160,
              width: double.infinity,
              cacheHeight: cozmeSiniri(context, 160),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, _, _) => Container(
                height: 48,
                // YON-DUYARLI: Arapca'da saga hizalanir.
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 20),
                    const SizedBox(width: 8),
                    // Dar ekranda (320 dp) satira sigmiyor — sar.
                    Expanded(child: Text(context.l10n.talepGorselYuklenemedi)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                // Etiketsiz gorsel ekran okuyucuda HIC duyurulmaz (tur 34).
                semanticLabel: context.l10n.ortakFotograf,
                // TAM EKRAN + yakinlastirma: sinir ekran genisliginin IKI
                // KATI. 4000 px'lik ham fotografi cozmek yerine 2x zoom'a
                // kadar net kalan bir sinir (tur 61).
                cacheWidth: cozmeSiniri(
                  routeContext,
                  MediaQuery.sizeOf(routeContext).width * 2,
                ),
                errorBuilder: (_, _, _) => Text(
                  routeContext.l10n.talepGorselYuklenemedi,
                  style: const TextStyle(color: Colors.white),
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
  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final file = await ref
          .read(imagePickerProvider)
          .pickImage(
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
        _photoError = _l10n.gorevFotoAlinamadi('$e');
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
            ? _l10n.gorevFotoOnlineGerekli
            : apiHataMetni(_l10n, e);
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
        _error = _l10n.gorevFotoHenuzYuklenmedi;
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
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                editing ? l10n.duyuruDuzenleBaslik : l10n.duyuruYeni,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baslikCtrl,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.talepBaslikAlan,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.duyuruBaslikZorunlu
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _govdeCtrl,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.duyuruMetniAlan,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.duyuruMetniZorunlu
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
                    // Uzun ceviri (ru/de) 320 dp'de satiri tasiriyordu (tur 38).
                    Expanded(child: Text(l10n.etkGorselAlan)),
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
                      label: Text(
                        _photoPath == null
                            ? l10n.gorevKamera
                            : l10n.gorevYenidenCek,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _photoBusy || _saving
                          ? null
                          : () => _pickAndUploadPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        l10n.gorevGaleridenSec,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_photoPath != null && _fotoKey == null)
                      TextButton.icon(
                        onPressed: _photoBusy || _saving ? null : _retryUpload,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          l10n.gorevTekrarYukle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_photoPath != null)
                      TextButton.icon(
                        onPressed: _photoBusy || _saving ? null : _removePhoto,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          l10n.gorevKaldir,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        ? l10n.gorevGonderiliyor
                        : editing
                        ? l10n.ortakKaydet
                        : l10n.duyuruYayinla,
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
