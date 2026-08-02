import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/metin_iste_diyalogu.dart';
import '../../../core/error/api_exception.dart';
import '../data/task_category_api.dart';
import '../domain/task_category_models.dart';
import '../../../core/error/akis_hatasi.dart';

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
      setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _ekle() async {
    final l10n = context.l10n;
    // (P110) Denetleyici artik DIYALOGUN KENDISINE ait; cikis
    // animasyonu bitince atilir (bkz. `metin_iste_diyalogu.dart`).
    final ad = await metinIste(
      context,
      baslik: l10n.gorevKategoriYeni,
      onayEtiketi: l10n.ortakEkle,
      etiket: l10n.gorevKategoriAdi,
      ipucu: l10n.gorevKategoriAdiIpucu,
      enFazla: 100,
    );
    if (ad == null || ad.isEmpty) return;
    try {
      await ref.read(taskCategoryApiProvider).create(ad);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.gorevKategoriEklendi(ad))));
      await _yenile();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.gorevKategoriEklenemedi(apiHataMetni(l10n, e))),
        ),
      );
    }
  }

  Future<void> _sil(TaskCategory kategori) async {
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.gorevKategoriSilinsinMi),
        content: Text(l10n.gorevKategoriSilOnay(kategori.ad)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(taskCategoryApiProvider).delete(kategori.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.gorevKategoriSilindi(kategori.ad))),
      );
      await _yenile();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.gorevKategoriSilinemedi(apiHataMetni(l10n, e))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final liste = _kategoriler;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.gorevKategorileriBaslik, context.dilKodu)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ekle,
        icon: const Icon(Icons.add),
        label: Text(l10n.gorevKategoriYeni),
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
                    child: Text(l10n.gorevKategoriListeAlinamadi(_hata!)),
                  ),
                ],
              );
            }
            if (liste == null || liste.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.gorevKategoriYokBos),
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
                    tooltip: l10n.ortakSil,
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
