import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/cameras_api.dart';
import '../domain/camera_models.dart';

/// Kamera yonetim ekrani (WP-F) — admin/yonetici kamera ekler/duzenler/siler;
/// security salt-okur (tikla → oynat). Hata ekrani DUSURMEZ.
class KameralarScreen extends ConsumerWidget {
  const KameralarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(camerasProvider);
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final yonetebilir =
        role == UserRole.admin || role == UserRole.yonetici;

    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Kameralar'))),
      floatingActionButton: yonetebilir
          ? FloatingActionButton.extended(
              onPressed: () => _formAc(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Kamera Ekle'),
            )
          : null,
      body: camerasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Kameralar yüklenemedi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (kameralar) {
          if (kameralar.isEmpty) {
            return const Center(child: Text('Kamera tanımı yok'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: kameralar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final k = kameralar[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(k.ad),
                  subtitle: Text(k.streamUrl,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () =>
                      context.push(AppRoutes.kameraIzle, extra: k),
                  trailing: yonetebilir
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Düzenle',
                              onPressed: () => _formAc(context, ref, mevcut: k),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Sil',
                              onPressed: () => _sil(context, ref, k),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref, Camera k) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kamerayı sil'),
        content: Text('"${k.ad}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(camerasApiProvider).delete(k.id);
      ref.invalidate(camerasProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _formAc(BuildContext context, WidgetRef ref, {Camera? mevcut}) {
    showDialog<void>(
      context: context,
      builder: (_) => _KameraForm(mevcut: mevcut),
    );
  }
}

class _KameraForm extends ConsumerStatefulWidget {
  const _KameraForm({this.mevcut});

  final Camera? mevcut;

  @override
  ConsumerState<_KameraForm> createState() => _KameraFormState();
}

class _KameraFormState extends ConsumerState<_KameraForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl =
      TextEditingController(text: widget.mevcut?.ad ?? '');
  late final TextEditingController _urlCtrl =
      TextEditingController(text: widget.mevcut?.streamUrl ?? '');
  bool _kaydediyor = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate() || _kaydediyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _kaydediyor = true);
    try {
      final api = ref.read(camerasApiProvider);
      final ad = _adCtrl.text.trim();
      final url = _urlCtrl.text.trim();
      if (widget.mevcut == null) {
        await api.create(ad: ad, streamUrl: url);
      } else {
        await api.update(widget.mevcut!.id, ad: ad, streamUrl: url);
      }
      ref.invalidate(camerasProvider);
      navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _kaydediyor = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mevcut == null ? 'Kamera Ekle' : 'Kamerayı Düzenle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _adCtrl,
              enabled: !_kaydediyor,
              decoration: const InputDecoration(
                labelText: 'Ad',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Ad zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlCtrl,
              enabled: !_kaydediyor,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Yayın URL (http/https)',
                hintText: 'https://nvr.example.com/kanal1.m3u8',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final url = (v ?? '').trim();
                if (url.isEmpty) return 'URL zorunludur';
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  return 'URL http:// veya https:// ile başlamalı';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _kaydediyor ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _kaydediyor ? null : _kaydet,
          child: _kaydediyor
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
