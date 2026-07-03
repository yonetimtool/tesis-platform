import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../nfc/presentation/nfc_controller.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';
import 'tasks_controller.dart';

/// Tek gorevin tamamlama akisinin durumu (NFC → foto → not → gonder).
class TaskCompleteState {
  const TaskCompleteState({
    required this.draft,
    this.nfcReading = false,
    this.nfcError,
    this.photoPath,
    this.photoBusy = false,
    this.photoError,
    this.submitting = false,
    this.submitError,
    this.result,
  });

  /// Gonderilecek taslak. `tamamlanma_zamani` ve Idempotency-Key akis
  /// BASLATILDIGI anda sabitlenmistir; kanit alanlari (nfc/foto/not)
  /// sonradan eklenir ama anahtar degismez → ag hatasinda ayni istegin
  /// tekrari backend'de cift kayit olusturmaz (200 idempotent tekrar).
  final TaskCompletionDraft draft;

  final bool nfcReading;
  final String? nfcError;

  /// Cekilen fotonun cihaz yolu (onizleme icin). `draft.fotoKey` dolu ise
  /// yukleme tamamlanmistir.
  final String? photoPath;

  /// Presign + PUT devam ediyor.
  final bool photoBusy;
  final String? photoError;

  final bool submitting;
  final String? submitError;

  /// Basarili gonderim sonucu (201 yeni / 200 idempotent tekrar).
  final TaskCompletionResult? result;

  bool get nfcOkundu => draft.nfcTagUid != null;
  bool get fotoYuklendi => draft.fotoKey != null;

  /// Foto secilmis ama yuklemesi bitmemis/basarisizsa gonderim beklemeli.
  bool get fotoBekliyor => photoPath != null && !fotoYuklendi;

  TaskCompleteState copyWith({
    TaskCompletionDraft? draft,
    bool? nfcReading,
    Object? nfcError = _sentinel,
    Object? photoPath = _sentinel,
    bool? photoBusy,
    Object? photoError = _sentinel,
    bool? submitting,
    Object? submitError = _sentinel,
    Object? result = _sentinel,
  }) {
    return TaskCompleteState(
      draft: draft ?? this.draft,
      nfcReading: nfcReading ?? this.nfcReading,
      nfcError: nfcError == _sentinel ? this.nfcError : nfcError as String?,
      photoPath:
          photoPath == _sentinel ? this.photoPath : photoPath as String?,
      photoBusy: photoBusy ?? this.photoBusy,
      photoError:
          photoError == _sentinel ? this.photoError : photoError as String?,
      submitting: submitting ?? this.submitting,
      submitError: submitError == _sentinel
          ? this.submitError
          : submitError as String?,
      result: result == _sentinel ? this.result : result as TaskCompletionResult?,
    );
  }

  static const Object _sentinel = Object();
}

/// Gorev tamamlama controller'i (gorev basina bir tane — family by taskId).
///
///   * NFC: mevcut [NfcService] YENIDEN kullanilir (kopya yok) — okunan UID
///     taslaga islenir; eslesme dogrulamasi backend'dedir (422 → mesaj net
///     gosterilir).
///   * Foto: cek → `POST /uploads/presign` → presigned URL'e PUT →
///     `foto_key` taslaga islenir. ONLINE GEREKTIRIR (URL kisa omurlu);
///     baglanti yoksa kullaniciya net uyari (bilinen kisit, README §11).
///   * Gonder: `POST /tasks/{id}/completions` (Idempotency-Key sabit).
class TaskCompleteController extends Notifier<TaskCompleteState> {
  TaskCompleteController(this.taskId);

  final String taskId;

  @override
  TaskCompleteState build() {
    return TaskCompleteState(
      draft: TaskCompletionDraft(
        taskId: taskId,
        tamamlanmaZamani: DateTime.now().toUtc(),
      ),
    );
  }

  TaskApi get _api => ref.read(taskApiProvider);

  /// Mevcut NFC servisiyle tek etiket okur; UID taslaga islenir.
  Future<void> readNfc() async {
    if (state.nfcReading) return;
    state = state.copyWith(nfcReading: true, nfcError: null);
    final result = await ref.read(nfcServiceProvider).readSingleTag();
    if (!ref.mounted) return;
    if (result.isSuccess) {
      state = state.copyWith(
        nfcReading: false,
        draft: state.draft.copyWith(nfcTagUid: result.uid),
        nfcError: null,
      );
    } else {
      state = state.copyWith(
        nfcReading: false,
        nfcError: result.error ?? 'Etiket okunamadi.',
      );
    }
  }

  /// Foto cek/sec → presign → PUT → foto_key. [source]: kamera veya galeri.
  Future<void> pickAndUploadPhoto(ImageSource source) async {
    if (state.photoBusy) return;
    state = state.copyWith(photoBusy: true, photoError: null);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Kanit fotosu icin cozunurluk/kalite dusurulur (yukleme boyutu).
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (!ref.mounted) return;
      if (file == null) {
        // Kullanici vazgecti — mevcut secim korunur.
        state = state.copyWith(photoBusy: false);
        return;
      }

      final contentType = _contentTypeFor(file);
      state = state.copyWith(
        photoPath: file.path,
        // Eski yukleme gecersiz: yeni foto secildi.
        draft: state.draft.copyWith(fotoKey: null),
      );

      final ticket = await _api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      final bytes = await file.readAsBytes();
      await _api.uploadPhoto(
        ticket: ticket,
        bytes: bytes,
        contentType: contentType,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        photoBusy: false,
        draft: state.draft.copyWith(fotoKey: ticket.fotoKey),
        photoError: null,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        photoBusy: false,
        photoError: e.kind == ApiErrorKind.network
            ? 'Fotograf yuklemek icin internet baglantisi gerekli '
                '(yukleme adresi kisa omurlu). Baglanti gelince '
                '"Tekrar yukle" ile deneyin.'
            : e.message,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        photoBusy: false,
        photoError: 'Fotograf alinamadi: $e',
      );
    }
  }

  /// Secili fotoyu (varsa) yeniden yukler — presign URL'i suresi dolmus ya da
  /// yukleme yarim kalmis olabilir.
  Future<void> retryUpload() async {
    final path = state.photoPath;
    if (path == null || state.photoBusy) return;
    state = state.copyWith(photoBusy: true, photoError: null);
    try {
      final file = XFile(path);
      final contentType = _contentTypeFor(file);
      final ticket = await _api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      final bytes = await file.readAsBytes();
      await _api.uploadPhoto(
        ticket: ticket,
        bytes: bytes,
        contentType: contentType,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        photoBusy: false,
        draft: state.draft.copyWith(fotoKey: ticket.fotoKey),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        photoBusy: false,
        photoError: e.kind == ApiErrorKind.network
            ? 'Fotograf yuklemek icin internet baglantisi gerekli.'
            : e.message,
      );
    }
  }

  void removePhoto() {
    state = state.copyWith(
      photoPath: null,
      photoError: null,
      draft: state.draft.copyWith(fotoKey: null),
    );
  }

  void setNotlar(String value) {
    final trimmed = value.trim();
    state = state.copyWith(
      draft: state.draft.copyWith(notlar: trimmed.isEmpty ? null : trimmed),
    );
  }

  /// `POST /tasks/{id}/completions`. Basarida liste rozetini gunceller;
  /// 201/200 ayrimi [TaskCompleteState.result] uzerinden UI'a yansir.
  Future<void> submit() async {
    if (state.submitting || state.result != null) return;
    if (state.fotoBekliyor) {
      state = state.copyWith(
        submitError: 'Fotograf henuz yuklenmedi. Yuklemenin bitmesini '
            'bekleyin, "Tekrar yukle"yi deneyin veya fotoyu kaldirin.',
      );
      return;
    }
    state = state.copyWith(submitting: true, submitError: null);
    try {
      final result = await _api.submitCompletion(state.draft);
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false, result: result);
      ref
          .read(tasksControllerProvider.notifier)
          .markCompleted(state.draft.taskId, result);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        submitting: false,
        submitError: e.kind == ApiErrorKind.network
            ? 'Tamamlama gonderilemedi — internet baglantisi gerekli. '
                'Baglanti gelince tekrar "Tamamla"ya basin; ayni kayit '
                'cift olusmaz (Idempotency-Key sabit). Fotografli '
                'tamamlama offline desteklenmez (bilinen kisit).'
            : e.message,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        submitting: false,
        submitError: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
      );
    }
  }

  /// Basarili gonderim sonrasi YENI bir tamamlama baslatir (yeni an + yeni
  /// Idempotency-Key).
  void startNew() {
    state = TaskCompleteState(
      draft: TaskCompletionDraft(
        taskId: state.draft.taskId,
        tamamlanmaZamani: DateTime.now().toUtc(),
      ),
    );
  }

  String _contentTypeFor(XFile file) {
    if (file.mimeType != null) return file.mimeType!;
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final taskCompleteControllerProvider = NotifierProvider.family<
    TaskCompleteController, TaskCompleteState, String>(
  TaskCompleteController.new,
);
