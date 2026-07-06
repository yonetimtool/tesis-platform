import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:ndef_record/ndef_record.dart';

/// AN12196 yayinli ornek vektor (openapi.yaml ScanCreate orneginin kaynagi):
/// ENCPICCData 16B (32 hex), SDMMAC 8B (16 hex).
const _picc = 'EF963FF7828658A599F3041510671E88';
const _cmac = '94EED9EE65337086';

/// Well-known 'U' (URI) kaydindan tek kayitli NDEF mesaji uretir.
/// [prefixCode] NFC Forum URI on-ek kodu (0x04 = "https://").
NdefMessage uriMessage(String urlWithoutPrefix, {int prefixCode = 0x04}) {
  return NdefMessage(records: [
    NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // 'U'
      identifier: Uint8List(0),
      payload: Uint8List.fromList([prefixCode, ...utf8.encode(urlWithoutPrefix)]),
    ),
  ]);
}

NdefMessage textMessage(String text) {
  // Well-known 'T' kaydi: [durum byte'i, dil kodu, metin].
  return NdefMessage(records: [
    NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]), // 'T'
      identifier: Uint8List(0),
      payload: Uint8List.fromList([0x02, 0x74, 0x72, ...utf8.encode(text)]),
    ),
  ]);
}

void main() {
  final service = NfcService();

  group('parseSdm — v0 provisioning (URL sorgu parametreleri)', () {
    test('picc_data + cmac parametreli URL tam ayristirilir', () {
      final sdm = service.parseSdm(
        uriMessage('tesis.example/t?picc_data=$_picc&cmac=$_cmac'),
      );

      expect(sdm, isNotNull);
      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, _cmac);
      expect(sdm.isComplete, isTrue);
      expect(sdm.rawUrl, 'https://tesis.example/t?picc_data=$_picc&cmac=$_cmac');
    });

    test('kisa anahtarlar (e/c) da kabul edilir', () {
      final sdm = service.parseSdm(
        uriMessage('tesis.example/t?e=$_picc&c=$_cmac'),
      );

      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, _cmac);
      expect(sdm.isComplete, isTrue);
    });

    test('kucuk harfli hex BUYUK harfe normalize edilir', () {
      final sdm = service.parseSdm(
        uriMessage(
          'tesis.example/t?picc_data=${_picc.toLowerCase()}'
          '&cmac=${_cmac.toLowerCase()}',
        ),
      );

      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, _cmac);
    });

    test('cmac yoksa yalniz picc kalir, isComplete false', () {
      final sdm = service.parseSdm(
        uriMessage('tesis.example/t?picc_data=$_picc'),
      );

      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, isNull);
      expect(sdm.isComplete, isFalse);
    });

    test('yanlis uzunlukta picc_data (31 hex) yok sayilir', () {
      final kisa = _picc.substring(1); // 31 karakter
      final sdm = service.parseSdm(
        uriMessage('tesis.example/t?picc_data=$kisa&cmac=$_cmac'),
      );

      expect(sdm!.piccData, isNull);
      expect(sdm.cmac, _cmac);
      expect(sdm.isComplete, isFalse);
    });

    test('hex olmayan karakter iceren cmac yok sayilir', () {
      final bozuk = '${_cmac.substring(0, 15)}G'; // 'G' hex degil
      final sdm = service.parseSdm(
        uriMessage('tesis.example/t?picc_data=$_picc&cmac=$bozuk'),
      );

      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, isNull);
      expect(sdm.isComplete, isFalse);
    });

    test('SDM parametresiz URL: rawUrl korunur, alanlar null', () {
      final sdm = service.parseSdm(uriMessage('tesis.example/hakkinda'));

      expect(sdm, isNotNull);
      expect(sdm!.piccData, isNull);
      expect(sdm.cmac, isNull);
      expect(sdm.isComplete, isFalse);
      expect(sdm.rawUrl, 'https://tesis.example/hakkinda');
    });

    test('absolute-URI kaydi da ayristirilir', () {
      final message = NdefMessage(records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.absoluteUri,
          type: Uint8List.fromList(utf8.encode('U')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(
            'https://tesis.example/t?picc_data=$_picc&cmac=$_cmac',
          )),
        ),
      ]);

      final sdm = service.parseSdm(message);
      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, _cmac);
    });

    test('on-ek kodu 0x00: URL payload icinde tam gelir', () {
      final sdm = service.parseSdm(uriMessage(
        'https://tesis.example/t?picc_data=$_picc&cmac=$_cmac',
        prefixCode: 0x00,
      ));

      expect(sdm!.piccData, _picc);
      expect(sdm.cmac, _cmac);
    });
  });

  group('parseSdm — SDM olmayan etiketler (NTAG21x akisi bozulmaz)', () {
    test('null NDEF mesaji → null', () {
      expect(service.parseSdm(null), isNull);
    });

    test('URI kaydi olmayan mesaj (yalniz text) → null', () {
      expect(service.parseSdm(textMessage('merhaba')), isNull);
    });

    test('bos kayit listesi → null', () {
      expect(service.parseSdm(const NdefMessage(records: [])), isNull);
    });
  });
}
