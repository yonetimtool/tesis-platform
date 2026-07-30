/// TUR 63 — NFC DENETLEYICISININ DALLARI.
///
/// Ucuncu envanterin A maddesi: `nfc_controller` kapsami **7/27 = %26** idi —
/// dosyanin ucte ikisi hic kosmamisti. Sebep basit: ekran platform kanalina
/// bagli oldugu icin surusler onu cizmiyordu. Oysa denetleyicinin kendisi
/// platformdan BAGIMSIZ: servis bir saglayici arkasinda, sahtelenebiliyor.
///
/// Olculen dallar: basarili okuma, HATA KIMLIGI olmayan basarisiz okuma
/// (savunma dali → `bilinmeyen`), okuma surerken ikinci baslatma, iptal,
/// sifirlama ve **ekran kapanirken oturumun birakilmasi** (`onDispose`).
///
/// Son madde tur 37'nin urun hatasinin nobetcisidir: `onDispose` govdesinde
/// `ref.read` cagrilmasi Riverpod assertion'i atiyordu; servis referansi artik
/// `build()` icinde alinir. Test bunu KAPANMA yoluyla dogruluyor.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';
import 'package:mobile/src/features/nfc/domain/nfc_read_result.dart';
import 'package:mobile/src/features/nfc/presentation/nfc_controller.dart';

const _ios = NfcIosMetinleri(
  yaklastir: 'Yaklastir',
  okundu: 'Okundu',
  okunamadi: 'Okunamadi',
  iptal: 'Iptal',
);

class _SahteServis extends NfcService {
  _SahteServis(this.sonuc);
  final NfcReadResult sonuc;

  int okumaCagrisi = 0;
  int iptalCagrisi = 0;
  String? sonIptalMetni;

  @override
  Future<NfcReadResult> readSingleTag(NfcIosMetinleri ios) async {
    okumaCagrisi++;
    return sonuc;
  }

  @override
  Future<void> cancel({String? iptalMetni}) async {
    iptalCagrisi++;
    sonIptalMetni = iptalMetni;
  }
}

ProviderContainer _kap(_SahteServis servis) {
  final c = ProviderContainer(
    overrides: [nfcServiceProvider.overrideWithValue(servis)],
  );
  c.listen(nfcControllerProvider, (_, _) {});
  return c;
}

void main() {
  test('BASARILI okuma: status success, sonuc duruma yazilir', () async {
    final servis = _SahteServis(
      NfcReadResult(uid: '04:A1:B2:C3', readAt: DateTime(2026, 1, 1)),
    );
    final c = _kap(servis);
    addTearDown(c.dispose);
    await c.read(nfcControllerProvider.notifier).startReading(_ios);
    final d = c.read(nfcControllerProvider);
    expect(d.status, NfcStatus.success);
    expect(d.result?.uid, '04:A1:B2:C3');
    expect(d.hata, isNull);
    expect(d.hataDetay, isNull);
  });

  test('HATALI okuma: kimlik + detay duruma yazilir, sonuc TEMIZLENIR',
      () async {
    final servis = _SahteServis(
      const NfcReadResult(
        hata: NfcHatasi.oturumBaslatilamadi,
        hataDetay: 'platform: session busy',
      ),
    );
    final c = _kap(servis);
    addTearDown(c.dispose);
    final not = c.read(nfcControllerProvider.notifier);
    await not.startReading(_ios);
    final d = c.read(nfcControllerProvider);
    expect(d.status, NfcStatus.error);
    expect(d.hata, NfcHatasi.oturumBaslatilamadi);
    expect(d.hataDetay, 'platform: session busy');
    expect(d.result, isNull);
  });

  test('KIMLIKSIZ basarisizlik: `bilinmeyen` kimligine duser (savunma dali)',
      () async {
    // `isSuccess` false ama `hata` null — platform beklenmedik yanit verirse.
    final servis = _SahteServis(const NfcReadResult());
    final c = _kap(servis);
    addTearDown(c.dispose);
    await c.read(nfcControllerProvider.notifier).startReading(_ios);
    expect(c.read(nfcControllerProvider).hata, NfcHatasi.bilinmeyen);
  });

  test('OKUMA SURERKEN ikinci baslatma YOK SAYILIR', () async {
    final servis = _SahteServis(const NfcReadResult(uid: '04:A1'));
    final c = _kap(servis);
    addTearDown(c.dispose);
    final not = c.read(nfcControllerProvider.notifier);
    await Future.wait([not.startReading(_ios), not.startReading(_ios)]);
    expect(servis.okumaCagrisi, 1,
        reason: 'ikinci cagri `reading` durumunda erken donmeli');
  });

  test('IPTAL: servise iptal metni gecer, durum ready olur', () async {
    final servis = _SahteServis(const NfcReadResult(uid: '04:A1'));
    final c = _kap(servis);
    addTearDown(c.dispose);
    final not = c.read(nfcControllerProvider.notifier);
    await not.startReading(_ios);
    await not.cancel(iptalMetni: 'Vazgecildi');
    expect(servis.iptalCagrisi, greaterThanOrEqualTo(1));
    expect(servis.sonIptalMetni, 'Vazgecildi');
    expect(c.read(nfcControllerProvider).status, NfcStatus.ready);
  });

  test('SIFIRLA: sonuc ve hata temizlenir', () async {
    final servis = _SahteServis(const NfcReadResult(hata: NfcHatasi.kapali));
    final c = _kap(servis);
    addTearDown(c.dispose);
    final not = c.read(nfcControllerProvider.notifier);
    await not.startReading(_ios);
    expect(c.read(nfcControllerProvider).status, NfcStatus.error);
    not.reset();
    final d = c.read(nfcControllerProvider);
    expect(d.status, NfcStatus.ready);
    expect(d.hata, isNull);
    expect(d.result, isNull);
  });

  test('KAPANMA: acik oturum birakilir ve ASSERTION ATMAZ (tur 37 nobetcisi)',
      () async {
    final servis = _SahteServis(const NfcReadResult(uid: '04:A1'));
    final c = _kap(servis);
    await c.read(nfcControllerProvider.notifier).startReading(_ios);
    final oncekiIptal = servis.iptalCagrisi;
    // `onDispose` govdesinde `ref.read` cagrilsa burada assertion atardi.
    c.dispose();
    expect(servis.iptalCagrisi, oncekiIptal + 1,
        reason: 'ekran kapanirken NFC oturumu birakilmali');
  });
}
