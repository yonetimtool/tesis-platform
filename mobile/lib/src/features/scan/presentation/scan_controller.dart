import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
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
    this.hataKimligi,
  });

  final ScanSubmitStatus status;

  /// Basarili gonderimde (created/duplicate) donen kayit.
  final ScanEvent? event;

  /// SUNUCU hata metni (error durumunda dolu; zaten yerellestirilmis gelir).
  ///
  /// KIMLIK / METIN AYRIMI (README §15): denetleyici TR metin URETMEZ.
  /// `notMatched` durumunda mesaj YOKTUR — [status]'un kendisi kimliktir
  /// (ekran `l10n.nfcEslesmeYok` yazar). Siniflandirilamayan hata icin
  /// [hataKimligi] tasinir.
  final String? message;
  final AkisHatasi? hataKimligi;

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
        // Mesaj YOK: durum kendisi kimliktir (bkz. [ScanSubmitState.message]).
        state = const ScanSubmitState(status: ScanSubmitStatus.notMatched);
      } else {
        state = ScanSubmitState(
          status: ScanSubmitStatus.error,
          message: e.message,
        );
      }
    } catch (_) {
      state = const ScanSubmitState(
        status: ScanSubmitStatus.error,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    }
  }

  /// Yeni okumaya gecerken onceki gonderim durumunu temizler.
  void reset() => state = const ScanSubmitState();
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanSubmitState>(ScanController.new);
