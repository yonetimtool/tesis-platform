import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/support_api.dart';
import '../domain/support_models.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/ui/gorsel_cozme.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);

/// Destek (WP1 + WP-G) — yonetici -> Yonetio ekibi: taleplerim listesi (durum
/// cipi + admin cevabi + gorseller) + "Yeni Talep" formu (konu + aciklama +
/// opsiyonel gorsel). Erisim: FAB olusturma menusu (WP2.4).
class DestekScreen extends ConsumerWidget {
  const DestekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.destekBaslik)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _yeniTalep(context),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.destekYeniTalep),
      ),
      body: async.when(
        data: (items) => items.isEmpty
            ? Center(child: Text(context.l10n.destekTalepYok))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myTicketsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TicketCard(bilet: items[i]),
                ),
              ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.destekYuklenemedi('$e'),
                textAlign: TextAlign.center),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _yeniTalep(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _YeniTalepSheet(),
    );
  }
}

/// Yeni talep formu — konu + aciklama + opsiyonel gorsel (galeri/kamera).
/// Gorsel presign PUT ile yuklenir; basarida foto_key create'e gecer.
class _YeniTalepSheet extends ConsumerStatefulWidget {
  const _YeniTalepSheet();

  @override
  ConsumerState<_YeniTalepSheet> createState() => _YeniTalepSheetState();
}

class _YeniTalepSheetState extends ConsumerState<_YeniTalepSheet> {
  final _konuCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  Uint8List? _onizleme;
  String? _fotoKey;
  bool _fotoYukleniyor = false;
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _konuCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _fotoSec(ImageSource source) async {
    if (_fotoYukleniyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _fotoYukleniyor = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (file == null) {
        if (mounted) setState(() => _fotoYukleniyor = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final api = ref.read(supportApiProvider);
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
        SnackBar(content: Text(_l10n.gorevFotoAlinamadi('$e'))),
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

  Future<void> _gonder() async {
    if (_gonderiliyor) return;
    if (_konuCtrl.text.trim().isEmpty || _aciklamaCtrl.text.trim().isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _gonderiliyor = true);
    try {
      await ref.read(supportApiProvider).create(
            konu: _konuCtrl.text.trim(),
            aciklama: _aciklamaCtrl.text.trim(),
            fotoKey: _fotoKey,
          );
      ref.invalidate(myTicketsProvider);
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.destekGonderilemedi('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.destekYeniTalepBaslik,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _konuCtrl,
            decoration: InputDecoration(
                labelText: l10n.destekKonu,
                border: const OutlineInputBorder()),
            maxLength: 200,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aciklamaCtrl,
            decoration: InputDecoration(
                labelText: l10n.talepAciklamaAlan,
                border: const OutlineInputBorder()),
            maxLines: 4,
            maxLength: 4000,
          ),
          const SizedBox(height: 8),
          // `Row` -> `Wrap`: Rusca "Прикрепить изображение" 320 dp'de satiri
          // 60 px tasiriyordu (tur 38). Dar ekranda dugmeler alt satira gecer.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_onizleme != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_onizleme!,
                      width: 56, height: 56, fit: BoxFit.cover),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _fotoYukleniyor ? null : _fotoSecMenu,
                icon: _fotoYukleniyor
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _onizleme == null
                      ? l10n.destekGorselEkle
                      : l10n.destekGorseliDegistir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_onizleme != null)
                TextButton(
                  onPressed: _fotoYukleniyor
                      ? null
                      : () => setState(() {
                            _onizleme = null;
                            _fotoKey = null;
                          }),
                  child: Text(l10n.gorevKaldir),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _gonderiliyor ? null : _gonder,
            child: _gonderiliyor
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l10n.talepGonder),
          ),
        ],
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

/// 72dp yuvarlatilmis ag gorseli — yuklenemezse kart BOZULMAZ (gizlenir).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        // Etiketsiz gorsel ekran okuyucuda HIC duyurulmaz (tur 34).
        semanticLabel: context.l10n.ortakFotograf,
        width: 72,
        height: 72,
        cacheWidth: cozmeSiniri(context, 72),
        cacheHeight: cozmeSiniri(context, 72),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.bilet});

  final SupportTicket bilet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cozuldu = bilet.durum == 'cozuldu';
    final renk = cozuldu ? _green : _amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(bilet.konu,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    cozuldu
                        ? context.l10n.talepDurumCozuldu
                        : context.l10n.talepDurumAcik,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: renk, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(bilet.aciklama,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            if (bilet.fotoUrl != null) ...[
              const SizedBox(height: 10),
              _Thumbnail(url: bilet.fotoUrl!),
            ],
            if (bilet.adminCevap != null || bilet.adminCevapFotoUrl != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.destekEkip,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: _green, fontWeight: FontWeight.w700)),
                    if (bilet.adminCevap != null) ...[
                      const SizedBox(height: 2),
                      Text(bilet.adminCevap!, style: theme.textTheme.bodySmall),
                    ],
                    if (bilet.adminCevapFotoUrl != null) ...[
                      const SizedBox(height: 8),
                      _Thumbnail(url: bilet.adminCevapFotoUrl!),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
