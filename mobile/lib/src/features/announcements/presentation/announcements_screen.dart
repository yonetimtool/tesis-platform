import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
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
        title: const Text('Duyurular'),
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
            edit == null ? 'Duyuru yayinlandi ✓' : 'Duyuru guncellendi ✓',
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
          Center(child: Text('Henuz duyuru yok.')),
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
                    tooltip: 'Islemler',
                    onSelected: (v) async {
                      if (v == 'edit') onEdit(a);
                      if (v == 'delete') await _confirmDelete(context, ref, a);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Duzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.govde),
            const SizedBox(height: 8),
            Text(
              '${a.olusturanAd ?? 'Yonetim'} · ${_fmtDateTime(a.createdAt.toLocal())}'
              '${a.duzenlendi ? ' · duzenlendi' : ''}',
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
            child: const Text('Iptal'),
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

/// Olustur/duzenle formu (bottom sheet). Sunucu sinirlari istemcide de
/// uygulanir: baslik <= 200, govde <= 5000, bos deger gonderilmez.
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = AnnouncementDraft(
      baslik: _baslikCtrl.text.trim(),
      govde: _govdeCtrl.text.trim(),
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
          _error = 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Duyuru duzenle' : 'Yeni duyuru',
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
                      ? 'Gonderiliyor...'
                      : editing
                          ? 'Kaydet'
                          : 'Yayinla',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
