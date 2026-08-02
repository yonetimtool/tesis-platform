/// (P119) iOS NFC — TARAMA SEÇENEĞİ ↔ Info.plist BEYANI KİLİDİ.
///
/// CİHAZ BULGUSU (iPhone 15, iOS 26.5.2, TestFlight yapım 2): oturum
/// `begin()` anında **NFCError code 2 — "Missing required entitlement"**
/// ile düşüyordu. Yetkilendirme tarafı KANITLI doğruydu: `codesign` ikili
/// dosyada, `security cms` gömülü profilde NDEF+TAG gösteriyordu, portalda
/// App ID yeteneği açıktı, temiz kurulum ve yeniden başlatma denenmişti.
///
/// KÖK NEDEN eksik bir yetkilendirme değil, eksik bir **beyandı**:
/// `NFCTagReaderSession`a `.iso18092` (FeliCa) tarama seçeneği verildiğinde
/// CoreNFC, uygulamanın `Info.plist`te
/// `com.apple.developer.nfc.readersession.felica.systemcodes` altında
/// okuyacağı sistem kodlarını beyan etmiş olmasını ŞART KOŞAR. Beyan yoksa
/// oturumu açmaz ve verdiği hata — yanıltıcı biçimde — bir yetkilendirme
/// hatasıdır. Aynı belirtiyi birebir aynı üç seçenekle bildiren iki forum
/// kaydı var; ikincisinde bildiren kişi ".iso18092'yi çıkarınca her şey
/// çalıştı" diyor (developer.apple.com/forums/thread/811220, .../735183).
///
/// BU KİLİT NE ÖLÇER: seçenek listesi ile `Info.plist` beyanı arasındaki
/// TUTARLILIĞI. `.iso18092` geri eklenirse, ancak sistem kodları da beyan
/// edilmişse geçer. Yani hata bir daha sessizce geri gelemez.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

const _plist = 'ios/Runner/Info.plist';
const _felika = 'com.apple.developer.nfc.readersession.felica.systemcodes';

void main() {
  final plist = File(_plist).readAsStringSync();

  test('iso18092 SECILIYORSA felica sistem kodlari BEYAN EDILMIS olmali', () {
    // Kilidin ASIL cumlesi. Iki taraftan biri degisirse duser.
    final felikaBeyani = plist.contains(_felika);
    final iso18092 = pollingSecenekleri.contains(NfcPollingOption.iso18092);
    expect(
      iso18092 && !felikaBeyani,
      isFalse,
      reason: 'iso18092 seciliyken $_felika beyani YOK — CoreNFC oturumu '
          '"Missing required entitlement" ile reddeder (cihazda olculdu)',
    );
  });

  test('SU ANKI durum: iso18092 YOK, felica beyani da YOK', () {
    // Tutarliligin HANGI ucundan saglandigini da yaziya dokuyoruz;
    // yoksa yukaridaki test, ikisi de degisince sessizce gecerdi.
    expect(pollingSecenekleri.contains(NfcPollingOption.iso18092), isFalse);
    expect(plist.contains(_felika), isFalse,
        reason: 'kullanmadigimiz bir FeliCa sistem kodunu beyan etmek, '
            'denetimde savunulamayacak gercek disi bir beyandir');
  });

  test('iso14443 VAR — etiketimiz (NTAG424 DNA) bu ailededir', () {
    expect(pollingSecenekleri, contains(NfcPollingOption.iso14443));
  });

  group('oturum hatasi KODA gore siniflanir', () {
    test('YETKILENDIRME/BEYAN hatasi IPTAL sayilmaz', () {
      // ASIL YANLIS ETIKETLEME. Cihazda "Missing required entitlement"
      // ekrana "Okuma iptal edildi: ..." diye ciktu; iptal demek
      // "tekrar deneyin" demektir, oysa YAPIM duzelmeden hicbir deneme
      // tutmaz. Iki tur bu yuzden yanlis yerde arandi.
      expect(
        iosHatasiCoz(NfcReaderErrorCodeIos.readerErrorSecurityViolation),
        NfcHatasi.yapilandirmaEksik,
      );
      expect(
        iosHatasiCoz(NfcReaderErrorCodeIos.readerErrorUnsupportedFeature),
        NfcHatasi.yapilandirmaEksik,
      );
    });

    test('GERCEK iptal ve zaman asimi hala okumaIptal', () {
      expect(
        iosHatasiCoz(
            NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled),
        NfcHatasi.okumaIptal,
      );
      expect(
        iosHatasiCoz(
            NfcReaderErrorCodeIos.readerSessionInvalidationErrorSessionTimeout),
        NfcHatasi.okumaIptal,
      );
    });

    test('NFC KAPALI kendi kimligine duser', () {
      expect(
        iosHatasiCoz(NfcReaderErrorCodeIos.readerErrorRadioDisabled),
        NfcHatasi.kapali,
      );
    });

    test('HER kod bir kimlige eslenir (eksik dal yok)', () {
      // `switch` ifadesinin butunlugu derleme zamaninda zorunlu ama
      // BURASI, eklenti yeni bir kod eklerse testin de haberdar
      // oldugunu gosterir: 22 kodun 22'si de cagrilir.
      for (final kod in NfcReaderErrorCodeIos.values) {
        expect(() => iosHatasiCoz(kod), returnsNormally, reason: '$kod');
      }
    });
  });
}
