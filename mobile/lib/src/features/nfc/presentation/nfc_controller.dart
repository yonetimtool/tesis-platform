import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nfc_service.dart';
import '../domain/nfc_hatasi.dart';
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
    this.hata,
    this.hataDetay,
  });

  final NfcStatus status;

  /// Basarili okumanin sonucu (UID, tag tipi, SDM).
  final NfcReadResult? result;

  /// Hata KIMLIGI (metin degil) + teknik detay — bkz. nfc_hatasi.dart.
  final NfcHatasi? hata;
  final String? hataDetay;

  NfcState copyWith({
    NfcStatus? status,
    Object? result = _sentinel,
    Object? hata = _sentinel,
    Object? hataDetay = _sentinel,
  }) {
    return NfcState(
      status: status ?? this.status,
      result: result == _sentinel ? this.result : result as NfcReadResult?,
      hata: hata == _sentinel ? this.hata : hata as NfcHatasi?,
      hataDetay:
          hataDetay == _sentinel ? this.hataDetay : hataDetay as String?,
    );
  }

  static const Object _sentinel = Object();
}

class NfcController extends Notifier<NfcState> {
  @override
  NfcState build() {
    // Servis REFERANSI simdi alinir: `onDispose` GOVDESINDE `ref.read`
    // cagirmak Riverpod'un yasakladigi seydir ("Cannot use Ref or modify
    // other providers inside life-cycles") ve ekran kapanirken assertion
    // atar. Tur 37'de bu ekran ILK KEZ cizilip kapatilinca ortaya cikti.
    final servis = ref.read(nfcServiceProvider);
    // Ekran kapanirsa acik oturumu birak.
    // context YOK: iOS sayfasi mesajsiz kapanir (bkz. cancel dokumani).
    ref.onDispose(servis.cancel);
    return const NfcState();
  }

  /// Okumayi baslatir; etiket okunana / hata olana kadar `reading` kalir.
  ///
  /// [ios] iOS sistem sayfasinin metinleri — CIZIM katmanindan gelir.
  Future<void> startReading(NfcIosMetinleri ios) async {
    if (state.status == NfcStatus.reading) return;
    state = state.copyWith(
      status: NfcStatus.reading,
      result: null,
      hata: null,
      hataDetay: null,
    );

    final result = await ref.read(nfcServiceProvider).readSingleTag(ios);

    if (result.isSuccess) {
      state = state.copyWith(
        status: NfcStatus.success,
        result: result,
        hata: null,
        hataDetay: null,
      );
    } else {
      state = state.copyWith(
        status: NfcStatus.error,
        result: null,
        hata: result.hata ?? NfcHatasi.bilinmeyen,
        hataDetay: result.hataDetay,
      );
    }
  }

  /// Devam eden okumayi iptal eder ve hazir duruma doner.
  Future<void> cancel({String? iptalMetni}) async {
    await ref.read(nfcServiceProvider).cancel(iptalMetni: iptalMetni);
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
