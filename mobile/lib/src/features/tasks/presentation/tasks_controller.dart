import 'dart:async';

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
    this.sadeceBenim = true,
    this.currentUserId,
    this.canManage = false,
    this.completedNow = const {},
    this.refreshedAt,
  });

  final bool loading;
  final String? errorMessage;

  /// 403 — rol gorev listesine erisemiyor (orn. resident).
  final bool forbidden;

  /// Aktif gorevler, sonraki_planlanan ASC. Varsayilan gorunum SUNUCUDA
  /// suzulur: `?atanan_user_id=me` (§11 #1 kapandi).
  final List<Task> tasks;

  /// Secili tip filtresi (null → tumu). Sunucuya `tip` parametresi gider.
  final TaskTip? tipFilter;

  /// true (varsayilan) → yalniz bana atananlar (`atanan_user_id=me`);
  /// false → tum aktif gorevler (havuz/atanmamislar dahil, eski gorunum).
  final bool sadeceBenim;

  /// JWT `sub` — "sana atanmis" vurgusu icin.
  final String? currentUserId;

  /// Rol admin/yonetici mi — "Yeni gorev" FAB'i + duzenle/sil menusu.
  /// Yalniz UX kapisi; gercek yetki backend RBAC'ta.
  final bool canManage;

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
    bool? sadeceBenim,
    Object? currentUserId = _sentinel,
    bool? canManage,
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
      sadeceBenim: sadeceBenim ?? this.sadeceBenim,
      currentUserId: currentUserId == _sentinel
          ? this.currentUserId
          : currentUserId as String?,
      canManage: canManage ?? this.canManage,
      completedNow: completedNow ?? this.completedNow,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Gorev listesi controller'i: varsayilan "bana atananlar" (sunucu suzmesi,
/// tek istek), istege bagli "tumu" gorunumu; tip filtresi sunucuya gider.
/// Tamamlama ekrani basariyla dondugunde [markCompleted] ile liste rozetini
/// gunceller.
class TasksController extends Notifier<TasksState> {
  bool _refreshing = false;

  /// Devam eden yenilemenin bitis isareti — kapsam degisiminde beklenir
  /// (eski kapsamla kosan fetch'in sonucunu yenisiyle ezmemek icin).
  Future<void>? _inflight;

  @override
  TasksState build() {
    Future.microtask(() async {
      // Saha disi yonetim rolleri (yonetici) icin varsayilan kapsam
      // "Herkes": onlara gorev atanmaz, "Bana atanan" bos gorunurdu.
      final role = await ref.read(currentUserRoleProvider.future);
      if (!role.isFieldWorker && state.sadeceBenim) {
        state = state.copyWith(sadeceBenim: false);
      }
      await refresh();
    });
    return const TasksState(loading: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final done = Completer<void>();
    _inflight = done.future;
    if (!silent) {
      state = state.copyWith(loading: true, errorMessage: null);
    }
    try {
      // JWT sub yalnizca "Sana atanmis" rozeti icin ("Tumu" gorunumunde);
      // suzme artik sunucuda.
      final userId = await ref.read(currentUserIdProvider.future);
      final role = await ref.read(currentUserRoleProvider.future);
      final tasks = await ref.read(taskApiProvider).fetchTasks(
            tip: state.tipFilter,
            assignedToMe: state.sadeceBenim,
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        forbidden: false,
        tasks: sortTasksByPlan(tasks),
        currentUserId: userId,
        canManage: role.canManageTasks,
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
        errorMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
      _inflight = null;
      done.complete();
    }
  }

  Future<void> setTipFilter(TaskTip? tip) async {
    if (tip == state.tipFilter) return;
    state = state.copyWith(tipFilter: tip);
    await refresh();
  }

  /// "Bana atanan" (sunucu suzmesi) ↔ "Tumu" gorunumu.
  Future<void> setSadeceBenim(bool value) async {
    if (value == state.sadeceBenim) return;
    state = state.copyWith(sadeceBenim: value);
    // Ilk yuklemeyle yaris: devam eden fetch ESKI kapsamla kosuyor olabilir
    // (giris noktasi kapsami initState'te set eder) — bitmesini bekleyip
    // yeni kapsamla tekrar cek.
    await _inflight;
    await refresh();
  }

  /// Gorev olustur — basarili olunca liste tazelenir; hata (orn. 422 atama
  /// kisiti) cagirana firlatilir, form icinde gosterilir.
  Future<void> createTask(TaskDraft draft) async {
    await ref.read(taskApiProvider).createTask(draft);
    await refresh(silent: true);
  }

  Future<void> updateTask(String id, TaskDraft draft) async {
    await ref.read(taskApiProvider).updateTask(id, draft);
    await refresh(silent: true);
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskApiProvider).deleteTask(id);
    await refresh(silent: true);
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
