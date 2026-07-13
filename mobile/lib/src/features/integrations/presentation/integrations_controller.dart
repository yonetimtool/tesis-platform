import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/integration_api.dart';
import '../domain/integration_models.dart';

class IntegrationsState {
  const IntegrationsState({
    this.loading = false,
    this.errorMessage,
    this.items = const [],
    this.presets = const [],
  });

  final bool loading;
  final String? errorMessage;
  final List<Integration> items;
  final List<IntegrationPreset> presets;

  IntegrationsState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    List<Integration>? items,
    List<IntegrationPreset>? presets,
  }) {
    return IntegrationsState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      items: items ?? this.items,
      presets: presets ?? this.presets,
    );
  }

  static const Object _sentinel = Object();
}

class IntegrationsController extends Notifier<IntegrationsState> {
  bool _refreshing = false;

  @override
  IntegrationsState build() {
    Future.microtask(refresh);
    return const IntegrationsState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final api = ref.read(integrationApiProvider);
      final items = await api.fetchAll();
      // Presetler bir kez yeter; hata olursa liste yine gosterilir.
      var presets = state.presets;
      if (presets.isEmpty) {
        try {
          presets = await api.fetchPresets();
        } on ApiException {
          presets = const [];
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        items: items,
        presets: presets,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> create(IntegrationDraft draft) async {
    await ref.read(integrationApiProvider).create(draft);
    await refresh();
  }

  Future<void> update(String id, IntegrationDraft draft) async {
    await ref.read(integrationApiProvider).update(id, draft);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(integrationApiProvider).delete(id);
    await refresh();
  }

  Future<TriggerResult> trigger(String id) {
    return ref
        .read(integrationApiProvider)
        .trigger(id, message: 'Test mesajı', title: 'Test');
  }
}

final integrationsControllerProvider =
    NotifierProvider<IntegrationsController, IntegrationsState>(
  IntegrationsController.new,
);
