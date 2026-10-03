import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';
import 'task_detail_screen.dart';

/// (P253 Asama 1) `GET /tasks/{id}` — tek gorev.
final tekGorevProvider = FutureProvider.autoDispose.family<Task, String>(
  (ref, id) => ref.watch(taskApiProvider).getTask(id),
);

/// (P253 Asama 1) DERIN BAGLANTI: `/tasks/detail?id=<gorev>`.
///
/// Detay onceden yalniz listeden secilen nesneyle (extra) acilabiliyordu;
/// bildirimden gelen bir `task_id` listeye dusuyordu ve sayfalanmis
/// listede gorev olmayabiliyordu. Kayit sunucudan TEK olarak cekilir;
/// gorunurluk kurali sunucuda (baskasinin gorevi 404).
class GorevYukleyici extends ConsumerWidget {
  const GorevYukleyici({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(tekGorevProvider(id))
        .when(
          data: (t) => TaskDetailScreen(task: t),
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakYuklenemedi,
                  key: const Key('gorev-yukleyici-hata'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
  }
}
