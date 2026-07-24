import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';

/// WP2.3: SOGUK ACILIS her zaman LOGIN'e duser — "beni hatirla" isaretli ve
/// gecerli refresh token VARKEN bile sessiz auto-login YAPILMAZ (alanlar
/// on-dolu gelir, kullanici Giris'e basar). Oturum-ici davranis degismez.
class _RememberliRepo implements AuthRepository {
  bool restoreCagrildi = false;

  @override
  Future<bool> restoreSession() async {
    restoreCagrildi = true;
    return true; // hatirla isaretli + refresh BASARILI olurdu
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('soguk acilis: restore BASARILI olacakken bile durum unauthenticated '
      '(login ekrani); sessiz auto-login yok', () async {
    final repo = _RememberliRepo();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    // build icindeki async baslangic isi tamamlansin.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(repo.restoreCagrildi, isFalse,
        reason: 'cold start artik sessiz restore denemez');
  });
}
