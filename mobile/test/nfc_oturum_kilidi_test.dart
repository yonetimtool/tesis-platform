/// NFC OTURUM YAŞAM DÖNGÜSÜ KİLİDİ — iOS `session_already_exists`.
///
/// CİHAZ BULGUSU (iPhone 15, iOS 26.5.2, ilk iOS koşumu): okuma ekranını
/// açıp okutmak
/// `PlatformException(session_already_exists, Multiple sessions cannot be
/// active at the same time.)` veriyordu. Donanım/yetkilendirme sağlamdı —
/// uygulama, **açık bir oturum dururken ikinci bir oturum** açıyordu.
///
/// KÖK NEDEN (eklentinin iOS kaynağında doğrulandı): native tarafta
/// `tagSession` değişkeni **yalnız `stopSession`da** nil'lenir;
/// `didInvalidateWithError` onu nil'LEMEZ. Yani kullanıcı sistem
/// sayfasını iptal ettiğinde / ~60 sn zaman aşımında, `stopSession`
/// çağrılmazsa native referans **asılı kalır** ve sonraki her `begin`
/// `session_already_exists` alır.
///
/// Android'de böyle bir tek-oturum kısıtı **yok** — hata bu yüzden
/// Android'de hiç görünmedi.
///
/// Bu dosya davranışı GERÇEK eklenti üzerinden ölçer: pigeon kanalı
/// taklit edilir ve **native tarafın kuralı da taklide gömülür**
/// (`begin` iki kez çağrılırsa `session_already_exists` atar). Yani test,
/// yalnız kendi kurgumuzu değil, cihazdaki kuralı ölçer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';

const _kok = 'dev.flutter.pigeon.nfc_manager';
const _uygun = '$_kok.HostApiPigeon.tagSessionReadingAvailable';
const _basla = '$_kok.HostApiPigeon.tagSessionBegin';
const _durdur = '$_kok.HostApiPigeon.tagSessionInvalidate';
const _gecersiz = '$_kok.FlutterApiPigeon.tagSessionDidInvalidateWithError';

/// iOS native davranışının taklidi.
class _SahteIos {
  _SahteIos(this._messenger);

  final TestDefaultBinaryMessenger _messenger;

  /// Native `tagSession` değişkeninin karşılığı: `begin` set eder,
  /// YALNIZ `invalidate` nil'ler (gerçek davranış).
  bool oturumVar = false;

  int beginSayisi = 0;
  int invalidateSayisi = 0;

  void kur() {
    for (final kanal in [_uygun, _basla, _durdur]) {
      _messenger.setMockMessageHandler(kanal, (mesaj) async {
        switch (kanal) {
          case _uygun:
            return _yanit(true);
          case _basla:
            beginSayisi++;
            if (oturumVar) {
              // NATIVE KURALI: NfcManagerPlugin.swift tagSessionBegin.
              return _hata(
                'session_already_exists',
                'Multiple sessions cannot be active at the same time.',
              );
            }
            oturumVar = true;
            return _yanit(null);
          case _durdur:
            invalidateSayisi++;
            if (!oturumVar) {
              return _hata('no_active_sessions', 'Session is not active.');
            }
            oturumVar = false;
            return _yanit(null);
        }
        return _yanit(null);
      });
    }
  }

  /// iOS'un oturumu KENDİLİĞİNDEN geçersiz kılması (kullanıcı iptali,
  /// zaman aşımı, arka plan). Native `tagSession`i **nil'lemez** —
  /// hatanın kaynağı tam olarak budur.
  ///
  /// [kod] varsayılanı 4 = `readerSessionInvalidationErrorUserCanceled`
  /// (kullanıcı sistem sayfasını kapattı); 2 = zaman aşımı.
  Future<void> gecersizKil({
    int kod = 4,
    String mesaj = 'Session invalidated',
  }) async {
    final govde = _pigeon.encodeMessage(<Object?>[_HataYuku(kod, mesaj)]);
    await _messenger.handlePlatformMessage(_gecersiz, govde, (_) {});
  }

  void kaldir() {
    for (final kanal in [_uygun, _basla, _durdur, _gecersiz]) {
      _messenger.setMockMessageHandler(kanal, null);
    }
  }
}

final _codec = const StandardMessageCodec();
ByteData? _yanit(Object? deger) => _codec.encodeMessage(<Object?>[deger]);
ByteData? _hata(String kod, String mesaj) =>
    _codec.encodeMessage(<Object?>[kod, mesaj, null]);

/// `NfcReaderSessionErrorPigeon` yuku (sinif eklentinin `src/` altinda,
/// disa acilmiyor).
class _HataYuku {
  const _HataYuku(this.kod, this.mesaj);
  final int kod;
  final String mesaj;
}

/// Eklentinin pigeon TEL BICIMINI birebir uretir.
///
/// NEDEN ELLE: `NfcReaderSessionErrorPigeon` ve codec'i `package:nfc_manager/
/// src/...` altinda ve disa acilmiyor. Duz `StandardMessageCodec` ise
/// eklentinin cozucusunde `type cast` hatasi verir (olculdu).
/// Tip kimlikleri `pigeon.g.dart`taki `writeValue`dan alindi:
/// 156 = NfcReaderSessionErrorPigeon, 137 = NfcReaderErrorCodePigeon.
class _PigeonYazici extends StandardMessageCodec {
  const _PigeonYazici();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is _HataYuku) {
      buffer.putUint8(156);
      writeValue(buffer, <Object?>[_EnumYuku(value.kod), value.mesaj]);
    } else if (value is _EnumYuku) {
      buffer.putUint8(137);
      writeValue(buffer, value.index);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

class _EnumYuku {
  const _EnumYuku(this.index);
  final int index;
}

const _pigeon = _PigeonYazici();

const _metinler = NfcIosMetinleri(
  yaklastir: 'yaklastir',
  okundu: 'okundu',
  okunamadi: 'okunamadi',
  iptal: 'iptal',
);

void main() {
  // Pigeon kanallarina dokunmadan ONCE baglama kurulmali.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SahteIos ios;
  late NfcService servis;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ios = _SahteIos(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
    )..kur();
    servis = NfcService();
  });

  tearDown(() {
    ios.kaldir();
    debugDefaultTargetPlatformOverride = null;
  });

  test('BASLANGIC durumu bosta', () {
    expect(servis.oturumDurumu, NfcOturum.bosta);
  });

  test('IPTAL/ZAMAN ASIMI sonrasi IKINCI okuma BASLAYABILIR', () async {
    // ASIL HATA BU. Once bir okuma baslat, sonra iOS oturumu kendiliginden
    // gecersiz kilsin (kullanici iptali). Duzeltmeden ONCE `stopSession`
    // hic cagrilmadigi icin native `tagSession` asili kalir ve ikinci
    // `begin` `session_already_exists` alirdi.
    final ilk = servis.readSingleTag(_metinler);
    await Future<void>.delayed(Duration.zero);
    expect(servis.oturumDurumu, NfcOturum.acik);

    await ios.gecersizKil();
    final ilkSonuc = await ilk;
    expect(ilkSonuc.isSuccess, isFalse);
    expect(ilkSonuc.hata, NfcHatasi.okumaIptal);

    // KANIT 1: native oturum GERCEKTEN kapatildi (stopSession cagrildi).
    expect(ios.invalidateSayisi, 1, reason: 'gecersiz kilinca stopSession cagrilmali');
    expect(ios.oturumVar, isFalse);
    expect(servis.oturumDurumu, NfcOturum.bosta);

    // KANIT 2: ikinci okuma BASLIYOR — "Tekrar oku" artik calisiyor.
    final ikinci = servis.readSingleTag(_metinler);
    await Future<void>.delayed(Duration.zero);
    expect(servis.oturumDurumu, NfcOturum.acik);
    await servis.cancel();
    await ikinci;
  });

  test('CIFT BASLATMA: ikinci okuma session_already_exists ALMAZ', () async {
    // Servis UC ekran arasinda PAYLASILIR; her ekranin kendi "zaten
    // okuyorum" bayragi var ama hicbiri otekini goremez. Ust uste iki
    // okuma istegi, muhafiz olmadan ikinci `begin`e giderdi.
    final a = servis.readSingleTag(_metinler);
    final b = servis.readSingleTag(_metinler);
    await Future<void>.delayed(Duration.zero);

    // Ikisi de baslatilmis olabilir AMA ikincisi oncekini temiz kapatir:
    // hicbir yerde `session_already_exists` gorunmemeli.
    await servis.cancel();
    final sonuclar = await Future.wait([a, b]);
    for (final s in sonuclar) {
      expect(
        s.hataDetay ?? '',
        isNot(contains('session_already_exists')),
        reason: 'oturum muhafizi cift baslatmayi engellemeli',
      );
    }
    expect(servis.oturumDurumu, NfcOturum.bosta);
  });

  test('IPTAL bekleyen okumayi SONLANDIRIR (Android dahil)', () async {
    // Eskiden Android'de `cancel` sonrasi `readSingleTag`in Future'i HIC
    // tamamlanmiyordu; iOS'ta tesadufen `onSessionErrorIos` tamamliyordu.
    final okuma = servis.readSingleTag(_metinler);
    await Future<void>.delayed(Duration.zero);

    await servis.cancel(iptalMetni: 'vazgecildi');
    final sonuc = await okuma.timeout(const Duration(seconds: 2));
    expect(sonuc.isSuccess, isFalse);
    expect(sonuc.hata, NfcHatasi.okumaIptal);
    expect(servis.oturumDurumu, NfcOturum.bosta);
    expect(ios.oturumVar, isFalse);
  });

  test('IPTAL, oturum YOKKEN de guvenli (durum bozulmaz)', () async {
    // `ref.onDispose` ekran hic okuma baslatmadan da cancel cagirir.
    await servis.cancel();
    expect(servis.oturumDurumu, NfcOturum.bosta);
    // Native'e gereksiz cagri GITMEZ: `no_active_sessions` gurultusu olmaz.
    expect(ios.invalidateSayisi, 0);
  });

  test('BASLATMA DUSERSE durum bosta kalir (kilitlenme yok)', () async {
    // Native'i "zaten oturum var" haline sok: ilk `begin` patlar.
    ios.oturumVar = true;
    final sonuc = await servis.readSingleTag(_metinler);
    expect(sonuc.isSuccess, isFalse);
    expect(sonuc.hata, NfcHatasi.oturumBaslatilamadi);
    // KRITIK: durum bosta DONMELI, yoksa bir daha hicbir okuma baslamazdi.
    expect(servis.oturumDurumu, NfcOturum.bosta);
  });

  test('ART ARDA UC iptal-tekrar dongusu bozulmaz', () async {
    for (var i = 0; i < 3; i++) {
      final okuma = servis.readSingleTag(_metinler);
      await Future<void>.delayed(Duration.zero);
      expect(servis.oturumDurumu, NfcOturum.acik, reason: 'tur $i');
      await ios.gecersizKil();
      await okuma;
      expect(servis.oturumDurumu, NfcOturum.bosta, reason: 'tur $i');
    }
    expect(ios.beginSayisi, 3);
    expect(ios.invalidateSayisi, 3);
  });
}
