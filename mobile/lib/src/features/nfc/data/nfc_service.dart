import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../domain/nfc_read_result.dart';
import '../domain/nfc_hatasi.dart';

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
///
/// METIN URETMEZ (README §15): hatalar [NfcHatasi] KIMLIGI olarak doner;
/// iOS'un sistem sayfasinda gorunecek metinler [NfcIosMetinleri] ile CIZIM
/// katmanindan gecirilir.
/// NFC oturumunun durumu — TEK SAHIP `NfcService` (iOS oturum kacagi).
///
/// iOS TEK OTURUM kuralini SERT uygular: eklentinin native tarafinda
/// `tagSession != nil` iken ikinci bir `begin`, `session_already_exists`
/// firlatir. Android boyle bir kisit uygulamaz — bu yuzden asagidaki
/// kacaklar Android'de HIC gorunmedi ve ilk iOS kosumunda ANINDA patladi.
enum NfcOturum {
  /// Acik oturum YOK.
  bosta,

  /// `startSession` cagrildi, platform yaniti bekleniyor.
  basliyor,

  /// Oturum acik; etiket ya da iptal bekleniyor.
  acik,

  /// `stopSession` cagrildi, kapanis bekleniyor.
  duruyor,
}

class NfcService {
  /// TEK SAHIP: oturum durumu YALNIZ burada degisir.
  ///
  /// Eskiden `bool _sessionActive` vardi ve UC AYRI kacagi vardi:
  ///
  /// 1. **`onSessionErrorIos` oturumu KAPATMIYORDU.** Kullanici sistem
  ///    sayfasinda iptal ettigi, ~60 sn zaman asimi doldugu ya da
  ///    uygulama arka plana gectigi anda iOS oturumu gecersiz kilar ve
  ///    bu geri cagriyi tetikler. Eski kod yalniz `completer`i
  ///    tamamliyordu; `stopSession` HIC cagrilmiyordu. Eklentinin iOS
  ///    tarafinda `tagSession` **yalniz `stopSession`da** nil'lenir
  ///    (`didInvalidateWithError` onu nil'LEMEZ) — yani native oturum
  ///    referansi ASILI KALIYOR ve sonraki her okuma
  ///    `session_already_exists` aliyordu. Uygulama yeniden acilana
  ///    kadar NFC TAMAMEN oluyordu.
  /// 2. **`readSingleTag` acik oturumu HIC DENETLEMIYORDU:** durumu
  ///    okumadan `startSession` cagiriyordu. Servis UC ekran arasinda
  ///    PAYLASILIR (NFC ekrani, gorev tamamlama, demirbas); her ekranin
  ///    kendi "zaten okuyorum" bayragi var ama hicbiri OTEKI ekrani
  ///    goremez.
  /// 3. **`cancel` bayrak bozulunca ISE YARAMIYORDU:** `_safeStop`
  ///    `!_sessionActive` ise ERKEN DONUYORDU. Yani (1) yuzunden bayrak
  ///    ile gercek ayrisinca kurtarma yolu da kapaliydi.
  NfcOturum _oturum = NfcOturum.bosta;

  /// Oturum GECISLERI (baslat/durdur) tek siraya dizilir.
  ///
  /// Etiket BEKLEME suresi bu sirada TUTULMAZ: aksi halde `cancel` kilidi
  /// beklerdi ve kullanici okumayi iptal edemezdi.
  Future<void> _sira = Future<void>.value();

  /// Bekleyen okuma — `cancel` bunu da sonlandirir.
  Completer<NfcReadResult>? _bekleyen;

  /// Testler icin durum penceresi; davranis kilidi buna bakar.
  @visibleForTesting
  NfcOturum get oturumDurumu => _oturum;

  /// Gecisleri SIRAYA dizer: iki okuma ayni anda istense bile ikinci
  /// `startSession`, birincinin kapanisi bittikten SONRA calisir.
  Future<void> _siraya(Future<void> Function() gorev) {
    final onceki = _sira;
    final tamam = Completer<void>();
    _sira = tamam.future;
    return onceki.then((_) => gorev()).whenComplete(tamam.complete);
  }

  /// Bekleyen okumayi TEK KEZ sonlandirir.
  void _tamamla(NfcReadResult sonuc) {
    final c = _bekleyen;
    if (c == null || c.isCompleted) return;
    _bekleyen = null;
    c.complete(sonuc);
  }

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
  Future<NfcReadResult> readSingleTag(NfcIosMetinleri ios) async {
    final avail = await availability();
    switch (avail) {
      case NfcAvailability.enabled:
        break;
      case NfcAvailability.disabled:
        return NfcReadResult.failure(NfcHatasi.kapali);
      case NfcAvailability.unsupported:
        return NfcReadResult.failure(NfcHatasi.desteklenmiyor);
    }

    final completer = Completer<NfcReadResult>();
    // YENI OKUMA ONCEKINI DEVRALIR. Servis TEK oturum sahibidir; iki
    // bekleyen okuma olamaz. Onceki cagriyi ASILI birakmak, cagiranin
    // `await`inin hic donmemesi demekti (kilit testi yakaladi) — ki bu,
    // duzeltmeye calistigimiz "asili oturum" hatasinin cagiran
    // tarafindaki ikizidir.
    _tamamla(NfcReadResult.failure(NfcHatasi.okumaIptal));
    _bekleyen = completer;

    await _siraya(() async {
      // ACIK OTURUM VARSA ONCE TEMIZ KAPAT (kacak 2'nin duzeltmesi).
      if (_oturum != NfcOturum.bosta) await _durdurIc();
      _oturum = NfcOturum.basliyor;
      try {
        await NfcManager.instance.startSession(
          // NTAG2xx/NTAG424 ISO 14443'tedir; digerlerini de tarayalim ki
          // "yanlis kart" durumunu da algilayip anlamli sonuc dondurelim.
          pollingOptions: {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
            NfcPollingOption.iso18092,
          },
          alertMessageIos: ios.yaklastir,
          onDiscovered: (tag) async {
            final result = _parseTag(tag);
            await _durdur(
              successIos: result.isSuccess ? ios.okundu : null,
              // Sistem sayfasinda TEK satir yer var; kimlige gore metin
              // uretmek yerine genel "okunamadi" gecilir.
              errorIos: result.isSuccess ? null : ios.okunamadi,
            );
            _tamamla(result);
          },
          onSessionErrorIos: (error) {
            // KACAK 1'IN DUZELTMESI. iOS oturumu gecersiz kildi
            // (kullanici iptali / zaman asimi / arka plan). Eklenti
            // native tarafta `tagSession`i NIL'LEMEZ; `stopSession`
            // cagrilmazsa referans asili kalir ve SONRAKI okuma
            // `session_already_exists` alir.
            _durdur().ignore();
            _tamamla(
              NfcReadResult.failure(
                NfcHatasi.okumaIptal,
                detay: error.message,
              ),
            );
          },
        );
        _oturum = NfcOturum.acik;
      } catch (e) {
        // Baslatma dustu: durum KESINLIKLE bosalir, aksi halde bir daha
        // hicbir okuma baslayamazdi.
        _oturum = NfcOturum.bosta;
        _tamamla(
          NfcReadResult.failure(NfcHatasi.oturumBaslatilamadi, detay: '$e'),
        );
      }
    });
    return completer.future;
  }

  /// Devam eden okuma oturumunu iptal eder (kullanici "vazgec" dediginde).
  ///
  /// [iptalMetni] iOS sistem sayfasinda gorunur; cizim katmanindan gelir.
  /// `ref.onDispose` gibi context'siz yollardan cagrildiginda null gecilir —
  /// sayfa mesajsiz kapanir (kabul edilebilir: kullanici zaten ekrandan cikti).
  Future<void> cancel({String? iptalMetni}) async {
    await _durdur(errorIos: iptalMetni);
    // KACAK 3'UN DUZELTMESI: bekleyen okuma da sonlandirilir. Eskiden
    // Android'de `cancel` sonrasi `readSingleTag`in Future'i HIC
    // tamamlanmiyordu (iOS'ta tesadufen `onSessionErrorIos` tamamliyordu).
    _tamamla(NfcReadResult.failure(NfcHatasi.okumaIptal));
  }

  /// Kapanisi SIRAYA dizer (baslatmayla yarismasin).
  Future<void> _durdur({String? successIos, String? errorIos}) =>
      _siraya(() => _durdurIc(successIos: successIos, errorIos: errorIos));

  /// Asil kapanis. ZATEN SIRADA cagrilir; kendini tekrar siraya dizmez
  /// (kilitlenirdi).
  Future<void> _durdurIc({String? successIos, String? errorIos}) async {
    if (_oturum == NfcOturum.bosta) return;
    _oturum = NfcOturum.duruyor;
    try {
      await NfcManager.instance.stopSession(
        alertMessageIos: successIos,
        errorMessageIos: errorIos,
      );
    } catch (_) {
      // Oturum zaten gecersiz kilinmis olabilir (kullanici iptali, zaman
      // asimi): eklenti `no_active_sessions` atar. Yutulur ama durum YINE
      // DE bosalir — eski kod burada erken donup bayragi ACIK birakiyor ve
      // kurtarma yolunu kapatiyordu.
    }
    _oturum = NfcOturum.bosta;
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
      return NfcReadResult.failure(NfcHatasi.desteklenmiyor);
    } catch (e) {
      return NfcReadResult.failure(NfcHatasi.cozumlenemedi, detay: '$e');
    }
  }

  NfcReadResult _parseAndroid(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null || androidTag.id.isEmpty) {
      return NfcReadResult.failure(NfcHatasi.uidOkunamadi);
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
      return NfcReadResult.failure(NfcHatasi.uidOkunamadi);
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

  /// NTAG424 SDM/SUN NDEF ciktisini `POST /scans` alanlarina ayristirir.
  ///
  /// v0 provisioning varsayimi (contracts/README.md + backend AN12196
  /// konfigurasyonu — UID+CTR aynali, ENCPICCData'li, SDMMAC girdisi bos):
  /// etiket, NDEF URI kaydindaki URL'e sorgu parametresi olarak
  /// `picc_data=<32 hex>` (ENCPICCData, 16B) + `cmac=<16 hex>` (SDMMAC, 8B)
  /// aynalar. Kisa adlar (`e`/`c`, NXP ornekleri) de kabul edilir.
  ///
  /// Burada GERCEK KRIPTO YOKTUR: deger yalniz format dogrulamasindan gecer
  /// (hex + uzunluk, BUYUK harfe normalize) — format tutmayan alan null kalir
  /// ki backend'e hic gonderilmesin. Dogrulama (PICC cozumu, CMAC, replay)
  /// backend'in isidir. URI kaydi yoksa (NTAG21x vb.) null doner; scan akisi
  /// SDM'siz aynen devam eder.
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
      piccData: _validHex(pick(['picc_data', 'piccdata', 'e']), length: 32),
      cmac: _validHex(pick(['cmac', 'c']), length: 16),
      encData: pick(['enc', 'd']),
      params: params,
    );
  }

  /// Degeri sozlesme formatina (tam [length] hex karakter) gore suzer;
  /// uyuyorsa BUYUK harfe normalize eder, uymuyorsa null doner.
  String? _validHex(String? value, {required int length}) {
    if (value == null || value.length != length) return null;
    if (!_hexPattern.hasMatch(value)) return null;
    return value.toUpperCase();
  }

  static final _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

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
