import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../domain/nfc_read_result.dart';

/// Uint8List UID'i sozlesme (contracts/openapi.yaml) formatina cevirir:
/// BUYUK HARF, IKI NOKTA (`:`) AYRACLI. Ornek: [0x04, 0xA3, 0xB2] -> "04:A3:B2".
///
/// Backend `nfc_tag_uid`'i tam string olarak eslestirir (Checkpoint/ScanCreate
/// ornekleri "04:A3:B2:C1:90:00"); mobil de ayni bicimi uretmezse okutma
/// hicbir checkpoint ile eslesmez (404).
String bytesToHex(Uint8List bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

/// NFC donanimiyla konusan tek nokta. UI'a ham platform nesnesi sizdirmaz;
/// her zaman [NfcReadResult] / [NfcAvailability] gibi tiplenmis sonuc doner ve
/// hicbir kosulda exception firlatip uygulamayi cokertmez.
class NfcService {
  bool _sessionActive = false;

  /// Cihazda NFC var mi / acik mi? Hata durumunda guvenli tarafta
  /// [NfcAvailability.unsupported] doner.
  Future<NfcAvailability> availability() async {
    try {
      return await NfcManager.instance.checkAvailability();
    } catch (_) {
      return NfcAvailability.unsupported;
    }
  }

  /// Tek bir etiket okur. Oturumu acar, ilk etiketi cozumler, oturumu kapatir.
  /// NFC kapali/yoksa veya hata olursa [NfcReadResult.failure] doner (cokme yok).
  Future<NfcReadResult> readSingleTag() async {
    final avail = await availability();
    switch (avail) {
      case NfcAvailability.enabled:
        break;
      case NfcAvailability.disabled:
        return NfcReadResult.failure(
          'NFC kapali. Lutfen cihaz ayarlarindan NFC\'yi acin.',
        );
      case NfcAvailability.unsupported:
        return NfcReadResult.failure('Bu cihaz NFC desteklemiyor.');
    }

    final completer = Completer<NfcReadResult>();
    try {
      _sessionActive = true;
      await NfcManager.instance.startSession(
        // NTAG2xx/NTAG424 ISO 14443'tedir; digerlerini de tarayalim ki
        // "yanlis kart" durumunu da algilayip anlamli sonuc dondurelim.
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Etiketi telefonun arkasina yaklastirin.',
        onDiscovered: (tag) async {
          final result = _parseTag(tag);
          await _safeStop(
            successIos: result.isSuccess ? 'Okundu' : null,
            errorIos: result.isSuccess ? null : (result.error ?? 'Okunamadi'),
          );
          if (!completer.isCompleted) completer.complete(result);
        },
        onSessionErrorIos: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              NfcReadResult.failure('Okuma iptal edildi: ${error.message}'),
            );
          }
        },
      );
    } catch (e) {
      await _safeStop();
      if (!completer.isCompleted) {
        completer.complete(
          NfcReadResult.failure('NFC oturumu baslatilamadi: $e'),
        );
      }
    }
    return completer.future;
  }

  /// Devam eden okuma oturumunu iptal eder (kullanici "vazgec" dediginde).
  Future<void> cancel() => _safeStop(errorIos: 'Iptal edildi');

  Future<void> _safeStop({String? successIos, String? errorIos}) async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      await NfcManager.instance.stopSession(
        alertMessageIos: successIos,
        errorMessageIos: errorIos,
      );
    } catch (_) {
      // Oturum zaten kapanmis olabilir; yutmak guvenli.
    }
  }

  /// Ham [NfcTag]'i platforma gore cozumler. Android ve iOS farkli sinif
  /// kumeleri sundugundan ikisini de dener.
  NfcReadResult _parseTag(NfcTag tag) {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return _parseAndroid(tag);
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return _parseIos(tag);
      }
      return NfcReadResult.failure('Desteklenmeyen platform.');
    } catch (e) {
      return NfcReadResult.failure('Etiket cozumlenemedi: $e');
    }
  }

  NfcReadResult _parseAndroid(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null || androidTag.id.isEmpty) {
      return NfcReadResult.failure('Etiket UID okunamadi.');
    }
    final uid = bytesToHex(androidTag.id);
    final tagType = _tagTypeFromTechList(androidTag.techList);

    NfcSdmData? sdm;
    if (tagType == NfcTagType.ntag424) {
      final ndef = NdefAndroid.from(tag);
      sdm = parseSdm(ndef?.cachedNdefMessage);
    }
    return NfcReadResult(
      uid: uid,
      tagType: tagType,
      sdmData: sdm,
      readAt: DateTime.now().toUtc(),
    );
  }

  NfcReadResult _parseIos(NfcTag tag) {
    final mifare = MiFareIos.from(tag);
    if (mifare == null || mifare.identifier.isEmpty) {
      return NfcReadResult.failure('Etiket UID okunamadi.');
    }
    final uid = bytesToHex(mifare.identifier);
    final tagType = switch (mifare.mifareFamily) {
      MiFareFamilyIos.ultralight => NfcTagType.ntag2xx,
      // NTAG424 DNA, iOS'ta DESFire ailesi olarak gorunur.
      MiFareFamilyIos.desfire => NfcTagType.ntag424,
      _ => NfcTagType.unknown,
    };

    NfcSdmData? sdm;
    if (tagType == NfcTagType.ntag424) {
      final ndef = NdefIos.from(tag);
      sdm = parseSdm(ndef?.cachedNdefMessage);
    }
    return NfcReadResult(
      uid: uid,
      tagType: tagType,
      sdmData: sdm,
      readAt: DateTime.now().toUtc(),
    );
  }

  /// Android teknoloji listesinden kaba tip tahmini.
  ///
  /// Heuristik: NTAG424 DNA `IsoDep` (ISO 14443-4) sunar; NTAG21x sunmaz ama
  /// `MifareUltralight` sunar. Kesin tip degil — backend GET_VERSION ile teyit
  /// etmeli.
  NfcTagType _tagTypeFromTechList(List<String> techList) {
    final has = techList.map((t) => t.toLowerCase()).toList();
    bool contains(String needle) => has.any((t) => t.contains(needle));

    if (contains('isodep')) return NfcTagType.ntag424;
    if (contains('mifareultralight')) return NfcTagType.ntag2xx;
    return NfcTagType.unknown;
  }

  /// NTAG424 SDM/SUN URL ISKELETI.
  ///
  /// NTAG424, NDEF icindeki bir URL'e dinamik olarak sifreli alanlar gomer
  /// (PICCData + CMAC). Burada GERCEK KRIPTO YOKTUR: yalnizca URL'i bulup
  /// sorgu parametrelerini yapilandirilmis sekilde dondururuz. Alan adlari
  /// etiketin SDM ayarina gore degisir; en yaygin adlari tarariz.
  ///
  /// Dogrulama (PICCData cozumu, CMAC kontrolu, replay) backend'de yapilir;
  /// mobil sadece okunan ham URL + alanlari iletir.
  NfcSdmData? parseSdm(NdefMessage? message) {
    if (message == null) return null;

    final url = _firstUri(message);
    if (url == null) return null;

    final uri = Uri.tryParse(url);
    final params = uri?.queryParameters ?? const <String, String>{};

    String? pick(List<String> keys) {
      for (final k in keys) {
        for (final entry in params.entries) {
          if (entry.key.toLowerCase() == k) return entry.value;
        }
      }
      return null;
    }

    return NfcSdmData(
      rawUrl: url,
      piccData: pick(['picc_data', 'piccdata', 'e']),
      cmac: pick(['cmac', 'c']),
      encData: pick(['enc', 'd']),
      params: params,
    );
  }

  /// NDEF mesajindan ilk URI'yi cozumler. URI iki bicimde gelebilir:
  /// well-known 'U' kaydi (payload[0] = on-ek kodu) veya absolute URI.
  String? _firstUri(NdefMessage message) {
    for (final record in message.records) {
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 /* 'U' */) {
        if (record.payload.isEmpty) continue;
        final prefix = _uriPrefix(record.payload[0]);
        final rest = utf8Safe(record.payload.sublist(1));
        return '$prefix$rest';
      }
      if (record.typeNameFormat == TypeNameFormat.absoluteUri) {
        return utf8Safe(record.payload);
      }
    }
    return null;
  }

  /// NFC Forum URI Record Type Definition on-ek tablosu (kismi; en yaygin
  /// degerler). Bilinmeyen kod icin bos string.
  String _uriPrefix(int code) {
    const prefixes = <int, String>{
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
      0x05: 'tel:',
      0x06: 'mailto:',
    };
    return prefixes[code] ?? '';
  }

  /// Baytlari guvenli sekilde UTF-8 string'e cevirir (gecersiz baytlari atlar).
  @visibleForTesting
  String utf8Safe(List<int> bytes) {
    try {
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    } catch (_) {
      return '';
    }
  }
}
