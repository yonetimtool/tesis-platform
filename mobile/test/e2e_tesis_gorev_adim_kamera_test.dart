/// (E2E 2026-09) MOBIL-7 + TESIS-03 — gorev ALT ADIMI ekrani.
///
/// MOBIL-7: adim fotografi `pickImage(camera)` try/catch'SIZDI; iOS'ta izin
/// reddinde `camera_access_denied` PlatformException yakalanmiyor, dugme
/// TEPKISIZ kaliyordu. Beklenen: once belirgin aciklama, sonra hata metni
/// ekranda; hicbir yukleme/tamamlama istegi atilmaz.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import 'package:mobile/src/features/tasks/presentation/task_detail_screen.dart';
import 'package:mobile/src/features/tasks/presentation/tasks_controller.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends TaskApi {
  _SahteApi() : super(Dio());
  int adimTamamlama = 0;
  int presign = 0;

  @override
  Future<List<TaskStep>> fetchSteps(String taskId) async => const [
        TaskStep(
          id: 's1',
          taskId: 'g-1',
          sira: 0,
          ad: 'A blok',
          fotoZorunlu: true,
        ),
      ];

  @override
  Future<List<TaskCompletion>> fetchCompletions(String taskId,
          {int limit = 20}) async =>
      const [];

  @override
  Future<PresignTicket> presignUpload({
    required String contentType,
    String? dosyaAdi,
  }) async {
    presign++;
    throw StateError('cagrilmamaliydi');
  }

  @override
  Future<TaskStep> completeStep(
    String taskId,
    String stepId, {
    String? fotoKey,
    String? notlar,
  }) async {
    adimTamamlama++;
    throw StateError('cagrilmamaliydi');
  }
}

class _ReddedenKamera extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    throw PlatformException(
      code: 'camera_access_denied',
      message: 'The user did not allow camera access.',
    );
  }
}

class _SahteListe extends TasksController {
  @override
  TasksState build() => const TasksState();

  @override
  Future<void> refresh({bool silent = false}) async {}
}

void main() {
  testWidgets('MOBIL-7: kamera izni reddi YAKALANIR ve metin gosterilir',
      (tester) async {
    final api = _SahteApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskApiProvider.overrideWithValue(api),
          imagePickerProvider.overrideWithValue(_ReddedenKamera()),
          currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
          taskCategoriesProvider.overrideWith((ref) async => const []),
          tasksControllerProvider.overrideWith(_SahteListe.new),
        ],
        child: l10nApp(
          const TaskDetailScreen(
            task: Task(id: 'g-1', ad: 'Kontrol', aktif: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dugme = find.byKey(const Key('gorev-adim-tamamla-s1'));
    // ListView tembel kurar: adim karti ekran disinda — kaydirarak bul.
    await tester.scrollUntilVisible(
      dugme,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(dugme);
    await tester.pumpAndSettle();
    // Belirgin aciklama (P141.5) — izin istenmeden ONCE amac.
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fotoğraf alınamadı'), findsOneWidget);
    expect(api.presign, 0);
    expect(api.adimTamamlama, 0);
  });
}
