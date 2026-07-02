import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nfc_service.dart';
import '../domain/nfc_read_result.dart';

/// NFC okuma ekraninin asamasi.
enum NfcStatus {
  /// Okumaya hazir, kullanici baslatabilir.
  ready,

  /// Oturum acik, etiket bekleniyor.
  reading,

  /// Etiket basariyla okundu.
  success,

  /// Okuma hata ile bitti.
  error,
}

/// NFC ekraninin tum durumunu tasiyan immutable model.
class NfcState {
  const NfcState({
    this.status = NfcStatus.ready,
    this.result,
    this.errorMessage,
  });

  final NfcStatus status;

  /// Basarili okumanin sonucu (UID, tag tipi, SDM).
  final NfcReadResult? result;

  /// Kullaniciya gosterilecek hata mesaji.
  final String? errorMessage;

  NfcState copyWith({
    NfcStatus? status,
    Object? result = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return NfcState(
      status: status ?? this.status,
      result: result == _sentinel ? this.result : result as NfcReadResult?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}

class NfcController extends Notifier<NfcState> {
  @override
  NfcState build() {
    ref.onDispose(() {
      // Ekran kapanirsa acik oturumu birak.
      ref.read(nfcServiceProvider).cancel();
    });
    return const NfcState();
  }

  /// Okumayi baslatir; etiket okunana / hata olana kadar `reading` kalir.
  Future<void> startReading() async {
    if (state.status == NfcStatus.reading) return;
    state = state.copyWith(
      status: NfcStatus.reading,
      result: null,
      errorMessage: null,
    );

    final result = await ref.read(nfcServiceProvider).readSingleTag();

    if (result.isSuccess) {
      state = state.copyWith(
        status: NfcStatus.success,
        result: result,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        status: NfcStatus.error,
        result: null,
        errorMessage: result.error ?? 'Bilinmeyen bir hata olustu.',
      );
    }
  }

  /// Devam eden okumayi iptal eder ve hazir duruma doner.
  Future<void> cancel() async {
    await ref.read(nfcServiceProvider).cancel();
    state = state.copyWith(status: NfcStatus.ready);
  }

  /// Sonuc/hata ekranindan tekrar okumaya doner.
  void reset() {
    state = const NfcState();
  }
}

final nfcServiceProvider = Provider<NfcService>((ref) => NfcService());

final nfcControllerProvider =
    NotifierProvider<NfcController, NfcState>(NfcController.new);
