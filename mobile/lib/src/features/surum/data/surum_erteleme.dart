/// (P202) ONERILEN uyarisinin ERTELEME kaydi.
///
/// ===========================================================================
/// NEDEN AYRI DOSYA — VE NEDEN `data` KATMANINDA
/// ===========================================================================
/// Depo anahtari bir CIZIM detayi degil, bir SAKLAMA detayidir. Denetleyici
/// (presentation) icinde durdugunda `sabit_metin_denetimi_test.dart` onu
/// "cevrilmemis sabit metin" olarak isaretledi — ve kilit HAKLIYDI: cizim
/// katmaninda ciplak dizge olmamali. Ayirmak hem kilidi hem katmanlamayi
/// duzeltir.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _anahtar = 'surum.onerilen_ertelendi';

/// "Sonra" denince ONERILEN uyarisinin susturuldugu sure.
///
/// ===========================================================================
/// NEDEN 24 SAAT
/// ===========================================================================
/// Iki yanlis ucu var:
///   * HER ACILISTA sormak — kullaniciyi "kapat" refleksine egitir. Uyari
///     bir sure sonra okunmadan kapatilan bir engele donusur ve ONERILEN
///     seviye anlamini yitirir; kotusu, ZORUNLU ekran ciktiginda da ayni
///     refleksle karsilanir.
///   * BIR HAFTA susturmak — onerilen guncellemeler cogunlukla duzeltme
///     tasir; kullaniciyi bir hafta bilinen bir hatayla birakmak, hatayi
///     duzeltmis olmanin degerini yok eder.
///
/// 24 saat ikisinin arasinda ve ANLASILIR bir soz verir: "gunde en fazla
/// bir kez". ZORUNLU seviye BU SUREDEN MUAFTIR ("sonra" secenegi yoktur).
const Duration kOnerilenErteleme = Duration(hours: 24);

class SurumErteleme {
  const SurumErteleme(this._depo);

  final FlutterSecureStorage _depo;

  /// Su an erteleme penceresi ICINDE miyiz.
  ///
  /// OKUNAMAYAN/BOZUK kayit "ertelenmemis" sayilir: uyariyi fazladan
  /// gostermek rahatsiz edicidir, ama gostermemek kullaniciyi bilinen
  /// bir hatayla bas basa birakir. Iki hatanin ucuzu secilir.
  Future<bool> ertelenmisMi() async {
    try {
      final ham = await _depo.read(key: _anahtar);
      if (ham == null) return false;
      final t = DateTime.tryParse(ham);
      if (t == null) return false;
      return DateTime.now().toUtc().difference(t) < kOnerilenErteleme;
    } catch (_) {
      return false;
    }
  }

  Future<void> ertele() async {
    try {
      await _depo.write(
        key: _anahtar,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Depo yazilamazsa uyari bir sonraki acilista yine cikar —
      // rahatsiz edici, ama KILITLEYICI DEGIL. Dogru geri-dusme bu.
    }
  }
}
