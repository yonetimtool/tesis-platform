import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/task_category_api.dart';
import '../domain/task_category_models.dart';

/// Gorev kategorisi yonetim ekrani (A6) — YALNIZ yonetici (+admin) girer;
/// giris noktasi "Görev yönetimi" ekranindaki AppBar aksiyonudur (canManage
/// kapisi orada). Ekle + soft-delete (sil = pasiflestir); liste ad sirali.
class TaskCategoriesScreen extends ConsumerStatefulWidget {
  const TaskCategoriesScreen({super.key});

  @override
  ConsumerState<TaskCategoriesScreen> createState() =>
      _TaskCategoriesScreenState();
}

class _TaskCategoriesScreenState extends ConsumerState<TaskCategoriesScreen> {
  List<TaskCategory>? _kategoriler;
  String? _hata;
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _yenile();
  }

  Future<void> _yenile() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final liste = await ref.read(taskCategoryApiProvider).fetchAll();
      if (!mounted) return;
      setState(() => _kategoriler = liste);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _ekle() async {
    final ctrl = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Kategori adı',
            hintText: 'örn. Havuz bakımı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (ad == null || ad.isEmpty) return;
    try {
      await ref.read(taskCategoryApiProvider).create(ad);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$ad" eklendi')),
      );
      await _yenile();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eklenemedi: ${e.message}')),
      );
    }
  }

  Future<void> _sil(TaskCategory kategori) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori silinsin mi?'),
        content: Text(
          '"${kategori.ad}" pasifleştirilir; mevcut görevlerin geçmişi '
          'korunur, yeni görevlerde seçilemez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(taskCategoryApiProvider).delete(kategori.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${kategori.ad}" silindi')),
      );
      await _yenile();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _kategoriler;
    return Scaffold(
      appBar: AppBar(title: const Text('Görev kategorileri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ekle,
        icon: const Icon(Icons.add),
        label: const Text('Yeni kategori'),
      ),
      body: RefreshIndicator(
        onRefresh: _yenile,
        child: Builder(
          builder: (context) {
            if (_yukleniyor && liste == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_hata != null && liste == null) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Liste alınamadı: $_hata'),
                  ),
                ],
              );
            }
            if (liste == null || liste.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Henüz kategori yok. Görev oluştururken seçilebilmesi '
                      'için "Yeni kategori" ile ekleyin.',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final k = liste[i];
                return ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(k.ad),
                  trailing: IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _sil(k),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
