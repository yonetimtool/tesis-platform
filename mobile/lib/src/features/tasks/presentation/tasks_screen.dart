import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/text/tr_upper.dart';
import '../../../routing/app_router.dart';
import '../data/task_category_api.dart';
import '../domain/task_models.dart';
import 'task_form_sheet.dart';
import 'task_tip_style.dart';
import 'tasks_controller.dart';

/// Gorev listesi — iki giris noktasi, TEK ekran (A4 kesin matris, auth.md §4):
///
///   * "Gorevlerim" (saha rolleri): YALNIZ kendine atanan gorevler (F4 kati —
///     havuz/grup gorunurlugu YOK; kapsam cipleri saha'da gizli). Tamamlama da
///     yalniz kendine atanan gorevde — backend zorlar (digeri 404).
///   * [yonetimGorunumu] (?gorunum=yonetim): Gorev-YONETIMI — YALNIZ
///     yonetici(+admin); tum gorev/atama takibi + "Yeni gorev" (canManage).
///
///   * Tip rozetli satirlar; "Sana atanmis" vurgulu; tip filtresi sunucuya
///     gider; pull-to-refresh; 403'te kibar mesaj.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.yonetimGorunumu = false});

  /// true → Gorev-YONETIMI gorunumu (tum liste); false → "Gorevlerim".
  final bool yonetimGorunumu;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  @override
  void initState() {
    super.initState();
    // Her iki giris noktasi da genis kapsamla acilir: saha rolu icin
    // "Gorevlerim" = kendi rol grubu + havuz (backend A4 boyle suzer);
    // yonetim gorunumu = tum liste. Kullanici "Bana atanan" cipiyle
    // kendine atananlara daraltabilir.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(tasksControllerProvider.notifier).setSadeceBenim(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksControllerProvider);
    final controller = ref.read(tasksControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(trUpper(widget.yonetimGorunumu ? 'Görev yönetimi' : 'Görevlerim')),
        actions: [
          // Kategori yönetimi (A6) — yalnız yönetim görünümünde ve
          // yetkili rolde (canManage); backend RBAC yazmayı ayrıca zorlar.
          if (widget.yonetimGorunumu && state.canManage)
            IconButton(
              tooltip: 'Kategoriler',
              icon: const Icon(Icons.label_outline),
              onPressed: () => context.push(AppRoutes.taskCategories),
            ),
        ],
      ),
      // Gorev olusturma admin + yonetici (auth.md §4) — UX kapisi; gercek
      // yetki backend'de.
      floatingActionButton: state.canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_task),
              label: const Text('Yeni görev'),
              onPressed: () async {
                final saved = await showTaskFormSheet(context);
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Görev oluşturuldu ✓')),
                  );
                }
              },
            )
          : null,
      body: Column(
        children: [
          _TipFilterBar(state: state, yonetim: widget.yonetimGorunumu),
          const Divider(height: 1),
          Expanded(
            child: state.loading && state.tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (state.errorMessage != null)
                          _ErrorBanner(
                            message: state.forbidden
                                ? 'Görev listesi için yetkiniz yok. Bu ekran '
                                    'temizlik ve güvenlik rollerine açıktır.'
                                : state.errorMessage!,
                            onRetry:
                                state.forbidden ? null : controller.refresh,
                          ),
                        if (state.tasks.isEmpty &&
                            state.errorMessage == null &&
                            !state.loading)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Bu filtreyle aktif görev yok.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        for (final task in state.tasks)
                          _TaskTile(task: task, state: state),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Kategori (gorev tipi) filtresi: "Tumu" + yonetici kategorileri + "Diğer".
/// Secim sunucuya `kategori_id` (UUID | 'diger') olarak gider.
class _TipFilterBar extends ConsumerWidget {
  const _TipFilterBar({required this.state, required this.yonetim});

  final TasksState state;

  /// Yonetim gorunumu mu — kapsam cipleri ("Bana atanan/Tum gorevler") YALNIZ
  /// burada anlamli. Saha rolu (F4 kati) yalniz kendine atanani gordugunden
  /// ciplerin ikisi de ayni sonucu verir → saha'da gizlenir.
  final bool yonetim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tasksControllerProvider.notifier);
    final kategoriler = ref.watch(taskCategoriesProvider).value ?? const [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Kapsam cipleri YALNIZ yonetim gorunumunde: "Bana atanan" (kendi) vs
          // "Tum gorevler" (tam liste). Saha rolu yalniz kendine atanani gorur
          // (F4 kati) → cipler gizli.
          if (yonetim) ...[
            ChoiceChip(
              avatar: const Icon(Icons.person, size: 16),
              label: const Text('Bana atanan'),
              selected: state.sadeceBenim,
              onSelected: (_) => controller.setSadeceBenim(true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.groups, size: 16),
              label: const Text('Tüm görevler'),
              selected: !state.sadeceBenim,
              onSelected: (_) => controller.setSadeceBenim(false),
            ),
            const SizedBox(width: 16),
          ],
          ChoiceChip(
            label: const Text('Tümü'),
            selected: state.kategoriFilter == null,
            onSelected: (_) => controller.setKategoriFilter(null),
          ),
          for (final k in kategoriler) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: taskKategoriStyle(k.ad).color,
                radius: 6,
              ),
              label: Text(k.ad),
              selected: state.kategoriFilter == k.id,
              onSelected: (_) => controller.setKategoriFilter(k.id),
            ),
          ],
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Diğer'),
            selected: state.kategoriFilter == 'diger',
            onSelected: (_) => controller.setKategoriFilter('diger'),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.state});

  final Task task;
  final TasksState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriler = ref.watch(taskCategoriesProvider).value;
    final adlar = (kategoriler ?? const [])
        .where((k) => k.id == task.kategoriId)
        .map((k) => k.ad);
    final style = taskKategoriStyle(
        task.kategoriId == null || adlar.isEmpty ? null : adlar.first);
    final mine = task.isAssignedTo(state.currentUserId);
    final completed = state.completedNow[task.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: style.color.withValues(alpha: 0.15),
          child: Icon(style.icon, color: style.color),
        ),
        title: Text(task.ad),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(style.label, style: TextStyle(color: style.color)),
            if (task.sonrakiPlanlanan != null)
              Text(
                'Planlanan: '
                '${_fmtDateTime(task.sonrakiPlanlanan!.toLocal())}',
              ),
            // "Bana atanan" gorunumunde her satir zaten benim — rozet
            // yalnizca "Herkes" gorunumunde ayirt edicidir.
            if (mine && !state.sadeceBenim)
              const Text(
                'Sana atanmış',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (task.fotoZorunlu)
              const Text(
                'Foto zorunlu',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (completed != null)
              Text(
                completed.wasDuplicate
                    ? 'Tamamlandı ✓ (zaten kayıtlıydı)'
                    : 'Tamamlandı ✓ (bu oturumda)',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        trailing: completed != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.taskDetail, extra: task),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () => onRetry!(),
                child: const Text('Tekrar dene'),
              ),
          ],
        ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _fmtDateTime(DateTime local) =>
    '${_two(local.day)}.${_two(local.month)}.${local.year} '
    '${_two(local.hour)}:${_two(local.minute)}';
