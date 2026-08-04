/// (P131) KAMERA ADRESİ KURALI — **ORTAK VAKA DOSYASI** ile ölçülür.
///
/// P131'de web'e de kamera yönetimi açıldı ve kural TypeScript'e de
/// yazıldı (`admin-web/lib/kamera-url.ts`). İki dil, iki uygulama: kopya
/// kaçınılmaz. Kaçınılmaz olmayan şey **sessizce ayrışmalarıdır**.
///
/// Bu test ile web'deki eşi (`admin-web/tests/kamera-url-kurali.test.ts`)
/// **aynı** dosyayı okur: `contracts/kamera-url-kurali.json`. Biri
/// ayrışırsa kendi tarafının testi düşer ve fark ölçülebilir olur.
///
/// `kamera_kaynak_kurali_test.dart` DURUYOR: o, kuralın *mobil
/// gerekçesini* (web sayfası adresleri) örneklerle anlatır; bu dosya
/// **sözleşmeyi** ölçer. İkisi farklı soruları cevaplar.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';

const _sozlesme = '../contracts/kamera-url-kurali.json';

/// `ozel: cokUzunUret` vakasının adresi çalışma anında üretilir — 2100
/// karakterlik bir dizeyi JSON'a gömmek dosyayı okunamaz yapardı.
String _adres(Map<String, dynamic> v) {
  if (v['ozel'] == 'cokUzunUret') return 'https://e.example/${'a' * 2100}';
  return (v['url'] as String?) ?? '';
}

/// Hata TÜRÜ -> sözleşmedeki karar adı. `null` = geçerli.
String _karar(CameraUrlHatasi? h) => switch (h) {
      null => 'gecerli',
      CameraUrlHatasi.bos => 'bos',
      CameraUrlHatasi.cokUzun => 'cokUzun',
      CameraUrlHatasi.webSayfasi => 'webSayfasi',
      CameraUrlHatasi.httpSemasiGerekli => 'httpSemasiGerekli',
      CameraUrlHatasi.rtspSemasiGerekli => 'rtspSemasiGerekli',
    };

CameraTur _tur(String w) => CameraTur.fromWire(w);

void main() {
  final dosya = File(_sozlesme);
  final veri = jsonDecode(dosya.readAsStringSync()) as Map<String, dynamic>;

  test('sözleşme dosyası okunabiliyor ve BOŞ DEĞİL', () {
    // Dosya bir gün yanlışlıkla boşalırsa aşağıdaki döngüler hiç
    // koşmaz ve test "geçer" — yani hiçbir şey ölçülmemiş olurdu.
    expect(dosya.existsSync(), isTrue, reason: _sozlesme);
    expect((veri['yayin'] as List).length, greaterThanOrEqualTo(10));
    expect((veri['anlik_kare'] as List).length, greaterThanOrEqualTo(4));
    expect((veri['restream'] as List).length, greaterThanOrEqualTo(4));
  });

  test('üst sınır sözleşmeyle AYNI', () {
    expect(kCameraUrlUstSinir, veri['ust_sinir']);
  });

  group('YAYIN adresi', () {
    for (final v in (veri['yayin'] as List).cast<Map<String, dynamic>>()) {
      test('${v['ozel'] ?? v['url']} (${v['tur']}) -> ${v['beklenen']}', () {
        expect(
          _karar(CameraDraft.urlHatasi(_adres(v), _tur(v['tur'] as String))),
          v['beklenen'],
        );
      });
    }
  });

  group('ANLIK KARE adresi', () {
    for (final v in (veri['anlik_kare'] as List).cast<Map<String, dynamic>>()) {
      test('${v['ozel'] ?? v['url']} -> ${v['beklenen']}', () {
        expect(_karar(CameraDraft.snapshotHatasi(_adres(v))), v['beklenen']);
      });
    }
  });

  group('RESTREAM adresi', () {
    for (final v in (veri['restream'] as List).cast<Map<String, dynamic>>()) {
      test('${v['ozel'] ?? v['url']} -> ${v['beklenen']}', () {
        expect(_karar(CameraDraft.restreamHatasi(_adres(v))), v['beklenen']);
      });
    }
  });
}
