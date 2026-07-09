import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../push/presentation/push_registrar.dart';
import '../data/auth_repository_impl.dart';

enum AuthStatus {
  /// Acilista saklanan oturum henuz kontrol edilmedi.
  unknown,

  /// Gecerli oturum yok → login ekrani.
  unauthenticated,

  /// Oturum acik → ana ekran.
  authenticated,
}

/// Auth ekraninin tum durumunu tasiyan immutable model.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.submitting = false,
    this.errorMessage,
  });

  final AuthStatus status;

  /// Login istegi devam ediyor mu (buton spinner'i icin).
  final bool submitting;

  /// Sozlesme hata zarfindan turetilmis, kullaniciya gosterilecek mesaj.
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    bool? submitting,
    Object? errorMessage = _sentinel,
  }) {
    return AuthState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Acilista saklanan oturumu (refresh token) async olarak kontrol et.
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    // "Beni hatirla" isaretliyse refresh denenir; degilse/basarisizsa login.
    final restored = await repo.restoreSession();
    state = state.copyWith(
      status: restored
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  /// Login dener; basari → authenticated, hata → errorMessage doldurulur.
  /// [rememberMe] true ise oturum kalici saklanir (sonraki acilis dogrudan
  /// ana ekran).
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(submitting: true, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).login(
            tenantSlug: tenantSlug,
            email: email,
            password: password,
            rememberMe: rememberMe,
          );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        submitting: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
      );
    }
  }

  Future<void> logout() async {
    // Push cihaz kaydini auth token'lar HENUZ gecerliyken pasiflestir
    // (DELETE /devices auth ister). Hatalari kendi icinde yutar — push
    // sorunu logout'u engellemez.
    await ref.read(pushRegistrarProvider.notifier).onLogout();
    await ref.read(authRepositoryProvider).logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// [AuthInterceptor] refresh'i kurtaramadiginda cagrilir (token'lar zaten
  /// silinmistir). Auth state'i `unauthenticated` yapar → router login'e doner.
  void onSessionExpired() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      submitting: false,
      errorMessage: 'Oturumunuz sona erdi. Lutfen tekrar giris yapin.',
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
