import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';

/// "Gorevlerim" listesinin durumu.
class TasksState {
  const TasksState({
    this.loading = false,
    this.errorMessage,
    this.forbidden = false,
    this.tasks = const [],
    this.tipFilter,
    this.currentUserId,
    this.completedNow = const {},
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// 403 — rol gorev listesine erisemiyor (orn. resident).
  final bool forbidden;

  /// Aktif gorevler — bana atananlar one, sonra sonraki_planlanan ASC
  /// (siralama istemcide; sunucuda "bana atananlar" filtresi yok —
  /// sozlesme dogrulandi, bkz. README §11).
  final List<Task> tasks;

  /// Secili tip filtresi (null → tumu). Sunucuya `tip` parametresi gider.
  final TaskTip? tipFilter;

  /// JWT `sub` — "sana atanmis" vurgusu icin.
  final String? currentUserId;

  /// BU OTURUMDA tamamlanan gorevler (taskId → sonuc): listede ✓ rozeti.
  /// Sunucudaki Task semasinda "tamamlandi" durumu yoktur (gorevler
  /// periyodiktir); kalici gecmis paneldedir.
  final Map<String, TaskCompletionResult> completedNow;

  final DateTime? refreshedAt;

  TasksState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    bool? forbidden,
    List<Task>? tasks,
    Object? tipFilter = _sentinel,
    Object? currentUserId = _sentinel,
    Map<String, TaskCompletionResult>? completedNow,
    DateTime? refreshedAt,
  }) {
    return TasksState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      forbidden: forbidden ?? this.forbidden,
      tasks: tasks ?? this.tasks,
      tipFilter:
          tipFilter == _sentinel ? this.tipFilter : tipFilter as TaskTip?,
      currentUserId: currentUserId == _sentinel
          ? this.currentUserId
          : currentUserId as String?,
      completedNow: completedNow ?? this.completedNow,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Gorev listesi controller'i: aktif gorevleri ceker, tip filtresi uygular,
/// bana atananlari one alir. Tamamlama ekrani basariyla dondugunde
/// [markCompleted] ile liste rozetini gunceller.
class TasksController extends Notifier<TasksState> {
  bool _refreshing = false;

  @override
  TasksState build() {
    Future.microtask(refresh);
    return const TasksState(loading: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      state = state.copyWith(loading: true, errorMessage: null);
    }
    try {
      final userId = await ref.read(currentUserIdProvider.future);
      final tasks =
          await ref.read(taskApiProvider).fetchTasks(tip: state.tipFilter);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        tasks: sortTasksForUser(tasks, userId),
        currentUserId: userId,
        refreshedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        forbidden: e.statusCode == 403,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> setTipFilter(TaskTip? tip) async {
    if (tip == state.tipFilter) return;
    state = state.copyWith(tipFilter: tip);
    await refresh();
  }

  /// Tamamlama akisi basarili oldugunda liste rozetini gunceller.
  void markCompleted(String taskId, TaskCompletionResult result) {
    state = state.copyWith(
      completedNow: {...state.completedNow, taskId: result},
    );
  }
}

final tasksControllerProvider =
    NotifierProvider<TasksController, TasksState>(TasksController.new);
