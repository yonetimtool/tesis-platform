// TUR 13 — `ApiException` i18n borcunun kapanisi.
//
// Tur 12'de olculen kalan borc: `core/error/api_exception.dart` UC adet TR
// cumle tasiyordu ("Sunucuya ulasilamadi" vb.) ve bunlar `e.message` ile
// uygulamanin HER yerine (143 kullanim / 66 dosya) siziyordu. Arapca UI'da
// baglanti kesildiginde ekranda Turkce cumle beliriyordu.
//
// Kapanis tasarimi — IKI KANAL:
//   * SUNUCU metni  → `ApiException.message` (istemci CEVIRMEZ, aynen gosterir)
//   * ISTEMCI hatasi → `ApiException.agHatasi` (KIMLIK; metin cizimde uretilir)
// Zarf gelmediyse `message` BOS'tur ve kimlik doludur. Cizim katmani ikisini
// `apiHataMetni(l10n, e)` ile birlestirir: sunucu metni varsa o, yoksa kimlik.
//
// Bu dosya sozlesmenin UC ayagini kilitler:
//   1. `core` artik hicbir dilde metin uretmez (kimlik + bos mesaj),
//   2. `apiHataMetni` 7 dilde de bos/Turkce-sizintisiz metin verir,
//      ve sunucu metni geldiginde ONU tercih eder,
//   3. modul kimlik enumlari ag hatasini kendi kanallarina cevirir
//      (`gorevAgHatasi`, `devriyeAgHatasi`, `girisAgHatasi`, `talepAgHatasi`,
//      `seffaflikAgHatasi`, `demirbasAgMesaji`, `okutmaAgKodu`).
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/assets/presentation/demirbas_mesaj_metni.dart';
import 'package:mobile/src/features/auth/domain/giris_hatasi.dart';
import 'package:mobile/src/features/auth/presentation/giris_hata_metni.dart';
import 'package:mobile/src/features/complaints/domain/talep_hata.dart';
import 'package:mobile/src/features/complaints/presentation/talep_hata_metni.dart';
import 'package:mobile/src/features/patrol/domain/patrol_hata.dart';
import 'package:mobile/src/features/patrol/presentation/devriye_hata_metni.dart';
import 'package:mobile/src/features/scan/domain/okutma_hata_kodu.dart';
import 'package:mobile/src/features/scan/presentation/okutma_hata_metni.dart';
import 'package:mobile/src/features/tasks/domain/task_hata.dart';
import 'package:mobile/src/features/tasks/presentation/gorev_hata_metni.dart';
import 'package:mobile/src/features/transparency/domain/seffaflik_hatasi.dart';

/// Uygulamanin destekledigi 7 dil (tr varsayilan).
const _diller = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];

/// YALNIZ Turkcede bulunan harfler. `ç/ö/ü` KASITLI olarak disarida: onlar
/// Almanca/Fransizca metinlerde de gecer ve yanlis alarm uretir
/// (orn. de "Zeituberschreitung" -> "Zeitüberschreitung").
final _trHarf = RegExp('[ğışĞİŞ]');

Future<AppLocalizations> _l10n(String kod) =>
    AppLocalizations.delegate.load(Locale(kod));

ApiException _dio(DioExceptionType t) => ApiException.fromDio(
      DioException(requestOptions: RequestOptions(path: '/x'), type: t),
    );

ApiException _sunucu(String mesaj, {int status = 422}) => ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: {
            'error': {'code': 'validation_error', 'message': mesaj}
          },
        ),
      ),
    );

void main() {
  group('core/error METIN uretmez (kimlik/metin ayrimi)', () {
    test('ag hatalarinda message BOS, agHatasi DOLU', () {
      for (final e in [
        _dio(DioExceptionType.connectionError),
        _dio(DioExceptionType.connectionTimeout),
        _dio(DioExceptionType.sendTimeout),
        _dio(DioExceptionType.receiveTimeout),
        _dio(DioExceptionType.unknown),
      ]) {
        expect(e.message, isEmpty);
        expect(e.agHatasi, isNotNull);
      }
    });

    test('kaynak dosyalarda TR cumle KALMADI', () {
      // Olcum: tur 12'de bu iki dosya 3 TR cumle tasiyordu.
      for (final yol in [
        'lib/src/core/error/api_exception.dart',
        'lib/src/core/error/akis_hatasi.dart',
      ]) {
        final satirlar = File(yol).readAsLinesSync();
        for (final s in satirlar) {
          final kod = s.split('//').first; // yorumlar TR olabilir
          expect(
            RegExp("'[^']*[çğışöüÇĞİŞÖÜ][^']*'").hasMatch(kod),
            isFalse,
            reason: '$yol: $s',
          );
        }
      }
    });
  });

  group('apiHataMetni 7 dilde', () {
    test('ag hatasi: metin BOS DEGIL ve TR disi dile sizmaz', () async {
      for (final dil in _diller) {
        final l10n = await _l10n(dil);
        for (final e in [
          _dio(DioExceptionType.connectionError),
          _dio(DioExceptionType.receiveTimeout),
          _dio(DioExceptionType.unknown),
        ]) {
          final metin = apiHataMetni(l10n, e);
          expect(metin, isNotEmpty, reason: '$dil / ${e.agHatasi}');
          if (dil != 'tr') {
            expect(_trHarf.hasMatch(metin), isFalse,
                reason: '$dil sizinti: $metin');
          }
        }
      }
    });

    test('zaman asimi ile ulasilamadi AYRI metinler', () async {
      for (final dil in _diller) {
        final l10n = await _l10n(dil);
        expect(
          apiHataMetni(l10n, _dio(DioExceptionType.receiveTimeout)),
          isNot(apiHataMetni(l10n, _dio(DioExceptionType.connectionError))),
          reason: dil,
        );
      }
    });

    test('SUNUCU metni geldiyse cevrilmez, aynen gosterilir', () async {
      for (final dil in _diller) {
        final l10n = await _l10n(dil);
        expect(apiHataMetni(l10n, _sunucu('Ödeme zaten alınmış')),
            'Ödeme zaten alınmış');
      }
    });

    test('zarf var / mesaj yok → kimlikten metin (bos ekran YOK)', () async {
      final e = ApiException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
          data: {
            'error': {'code': 'server_error'}
          },
        ),
      ));
      for (final dil in _diller) {
        expect(apiHataMetni(await _l10n(dil), e), isNotEmpty, reason: dil);
      }
    });
  });

  group('modul kimlik kanallari ag hatasini yutmaz', () {
    test('gorev / devriye / giris / talep / seffaflik', () {
      final zaman = _dio(DioExceptionType.receiveTimeout);
      final kopuk = _dio(DioExceptionType.connectionError);
      final sunucu = _sunucu('Gecersiz');

      expect(gorevAgHatasi(zaman), GorevAkisHatasi.agZamanAsimi);
      expect(gorevAgHatasi(kopuk), GorevAkisHatasi.agUlasilamadi);
      expect(gorevAgHatasi(sunucu), isNull); // sunucu metni kullanilir

      expect(devriyeAgHatasi(zaman), DevriyeAkisHatasi.agZamanAsimi);
      expect(devriyeAgHatasi(sunucu), isNull);

      expect(girisAgHatasi(kopuk), GirisAkisHatasi.agUlasilamadi);
      expect(girisAgHatasi(sunucu), isNull);

      expect(talepAgHatasi(zaman), TalepAkisHatasi.agZamanAsimi);
      expect(talepAgHatasi(sunucu), isNull);

      expect(seffaflikAgHatasi(kopuk), SeffaflikHatasi.agUlasilamadi);
      expect(seffaflikAgHatasi(sunucu), isNull);
    });

    test('demirbas: kimlik mesaji sunucu metninin ONUNE gecer', () async {
      final kopuk = _dio(DioExceptionType.connectionError);
      expect(demirbasAgMesaji(kopuk), isNotNull);
      expect(demirbasAgMesaji(_sunucu('Zimmet alinmis')), isNull);
      for (final dil in _diller) {
        final l10n = await _l10n(dil);
        final metin = demirbasMesajMetni(l10n, demirbasAgMesaji(kopuk)!);
        expect(metin, isNotEmpty, reason: dil);
        if (dil != 'tr') {
          expect(_trHarf.hasMatch(metin), isFalse, reason: '$dil: $metin');
        }
      }
    });

    // Kuyruk kaydi DISKE yazilir: cumle degil KOD tasimali (tur 11 kurali).
    test('kuyruk: ag hatasi diske KOD yazar, metin cizimde cozulur', () async {
      expect(okutmaAgKodu(_dio(DioExceptionType.receiveTimeout)),
          okutmaAgZamanAsimiKod);
      expect(okutmaAgKodu(_dio(DioExceptionType.connectionError)),
          okutmaAgUlasilamadiKod);
      expect(okutmaAgKodu(_sunucu('Etiket yok')), isNull);

      for (final dil in _diller) {
        final l10n = await _l10n(dil);
        for (final kod in [okutmaAgZamanAsimiKod, okutmaAgUlasilamadiKod]) {
          // Ag hatasinda sunucu metni BOS gelir — metin koddan uretilmeli.
          final metin = okutmaHataMetni(l10n, kod: kod, sunucuMetni: '');
          expect(metin, isNotEmpty, reason: '$dil/$kod');
          if (dil != 'tr') {
            expect(_trHarf.hasMatch(metin), isFalse, reason: '$dil: $metin');
          }
        }
        // Kod bilinmiyor + sunucu metni BOS → bos ekran degil, genel metin.
        expect(okutmaHataMetni(l10n, kod: 'x_yok', sunucuMetni: ''),
            isNotEmpty);
      }
    });
  });
}
