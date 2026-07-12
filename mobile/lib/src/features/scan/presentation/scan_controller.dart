import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/scan_api.dart';
import '../domain/scan.dart';

/// Tur kaniti gonderiminin asamasi.
enum ScanSubmitStatus {
  /// Henuz gonderilmedi (okuma sonucu bekliyor).
  idle,

  /// `POST /scans` devam ediyor.
  submitting,

  /// 201 — yeni kayit olusturuldu.
  created,

  /// 200 — ayni okutma zaten kayitliydi (idempotent).
  duplicate,

  /// 404 — UID hicbir checkpoint ile eslesmedi.
  notMatched,

  /// Ag/sunucu hatasi.
  error,
}

/// Gonderim ekraninin durumu.
class ScanSubmitState {
  const ScanSubmitState({
    this.status = ScanSubmitStatus.idle,
    this.event,
    this.message,
  });

  final ScanSubmitStatus status;

  /// Basarili gonderimde (created/duplicate) donen kayit.
  final ScanEvent? event;

  /// Hata/bilgi mesaji (notMatched/error durumunda dolu).
  final String? message;

  bool get inProgress => status == ScanSubmitStatus.submitting;
}

class ScanController extends Notifier<ScanSubmitState> {
  @override
  ScanSubmitState build() => const ScanSubmitState();

  /// Okunan etiketi backend'e gonderir. Ayni [draft] tekrar gonderilirse
  /// (ayni Idempotency-Key) backend mevcut kaydi doner → duplicate.
  Future<void> submit(ScanDraft draft) async {
    if (state.inProgress) return;
    state = const ScanSubmitState(status: ScanSubmitStatus.submitting);
    try {
      final result = await ref.read(scanApiProvider).submit(draft);
      state = ScanSubmitState(
        status: result.wasDuplicate
            ? ScanSubmitStatus.duplicate
            : ScanSubmitStatus.created,
        event: result.event,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        state = ScanSubmitState(
          status: ScanSubmitStatus.notMatched,
          message: 'Bu etiket hiçbir checkpoint ile eşleşmiyor.',
        );
      } else {
        state = ScanSubmitState(
          status: ScanSubmitStatus.error,
          message: e.message,
        );
      }
    } catch (_) {
      state = const ScanSubmitState(
        status: ScanSubmitStatus.error,
        message: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Yeni okumaya gecerken onceki gonderim durumunu temizler.
  void reset() => state = const ScanSubmitState();
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanSubmitState>(ScanController.new);
