/// (P200 §2) HATA KIMLIGI — `copyWith` YALNIZ enum kabul eder.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// `AuthController`in ON hata dalinda `hataKimligi: e.code` yaziliydi.
/// `e.code` bir **String**tir; `copyWith` ise degeri `GirisAkisHatasi?`
/// olarak cast eder. Yani sunucu bir hata dondurdugunde:
///
///   1. `catch (ApiException)` blogu calisiyor,
///   2. blogun ICINDE `TypeError` atiliyor,
///   3. istisna metottan disari sizip ekrani bekleme durumunda birakiyor.
///
/// Kullanicinin gordugu: sonsuza kadar donen bir dugme ve HICBIR hata
/// metni. Kaynaga bakarak "hata yakalaniyor" gorunuyordu — akis
/// surulmeden ortaya cikmadi.
///
/// Bu dosya kaliciligi saglar: dogru donusturucu (`girisAgHatasi`)
/// kullanilmazsa asagidaki testler duser.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/domain/giris_hatasi.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/giris_hata_metni.dart';

void main() {
  test('copyWith String hataKimligini KABUL ETMEZ — cagrilar enum vermeli',
      () {
    const s = AuthState();
    expect(
      () => s.copyWith(hataKimligi: 'invalid_credentials'),
      throwsA(isA<TypeError>()),
      reason: 'String gecirmek CALISMA ANINDA patlar; kaynak okumasi bunu '
          'gostermiyordu',
    );
  });

  test('SUNUCU HATASI: kimlik null, metin SUNUCUDAN gelir', () {
    // Sunucu bir zarf dondurduyse (`message` dolu) kimlik uretilmez —
    // kullaniciya sunucunun kendi cumlesi gosterilir.
    const e = ApiException(code: 'invalid_credentials', message: 'Parola hatali.');
    const s = AuthState();
    final yeni = s.copyWith(errorMessage: e.message, hataKimligi: girisAgHatasi(e));
    expect(yeni.hataKimligi, isNull);
    expect(yeni.errorMessage, 'Parola hatali.');
  });

  test('AG HATASI: kimlik URETILIR, metin cizimde cozulur', () {
    const e = ApiException(
      code: 'network_error',
      message: '',
      agHatasi: AkisHatasi.sunucuyaUlasilamadi,
    );
    const s = AuthState();
    final yeni = s.copyWith(errorMessage: e.message, hataKimligi: girisAgHatasi(e));
    expect(yeni.hataKimligi, GirisAkisHatasi.agUlasilamadi);
  });
}
