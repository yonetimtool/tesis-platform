import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../domain/task_models.dart';
import 'task_tip_style.dart';
import 'tasks_controller.dart';

/// "Gorevlerim" — temizlik/kontrol personelinin gorev listesi.
///
///   * Tip rozetli satirlar; bana atananlar one ve "Sana atanmis" vurgulu;
///     sonraki_planlanan varsa tarih gosterilir.
///   * Tip filtresi (chip'ler, sunucuya `tip` parametresi gider).
///   * Pull-to-refresh; 403'te kibar mesaj (liste cleaning + security +
///     admin'e aciktir).
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tasksControllerProvider);
    final controller = ref.read(tasksControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Gorevlerim')),
      body: Column(
        children: [
          _TipFilterBar(state: state),
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
                                ? 'Gorev listesi icin yetkiniz yok. Bu ekran '
                                    'temizlik ve guvenlik rollerine aciktir.'
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
                                'Bu filtreyle aktif gorev yok.',
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

/// Tip filtresi: "Tumu" + sozlesmedeki tipler. Secim sunucu sorgusuna gider.
class _TipFilterBar extends ConsumerWidget {
  const _TipFilterBar({required this.state});

  final TasksState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tasksControllerProvider.notifier);
    const tipler = [
      TaskTip.temizlik,
      TaskTip.kontrol,
      TaskTip.ilaclama,
      TaskTip.bakim,
      TaskTip.peyzaj,
      TaskTip.diger,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tumu'),
            selected: state.tipFilter == null,
            onSelected: (_) => controller.setTipFilter(null),
          ),
          for (final tip in tipler) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: taskTipStyle(tip).color,
                radius: 6,
              ),
              label: Text(taskTipStyle(tip).label),
              selected: state.tipFilter == tip,
              onSelected: (_) => controller.setTipFilter(tip),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.state});

  final Task task;
  final TasksState state;

  @override
  Widget build(BuildContext context) {
    final style = taskTipStyle(task.tip);
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
            if (mine)
              const Text(
                'Sana atanmis',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (completed != null)
              Text(
                completed.wasDuplicate
                    ? 'Tamamlandi ✓ (zaten kayitliydi)'
                    : 'Tamamlandi ✓ (bu oturumda)',
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
