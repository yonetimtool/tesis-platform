import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'dukkan_jeton_deposu.dart';
import 'dukkan_push.dart';

/// (DUKKAN F4) DUKKAN JETONU — Yonetiyor SSO koprusuyle alinir.
///
/// =========================================================================
/// NEDEN AYRI JETON
/// =========================================================================
/// Yonetiyor JWT'si `tenant_id` ZORUNLU tasir; Dukkan jetonu tasimaz
/// (Dukkan cok-kiracili degil). Iki jeton dunyasi ayri ve birbirinin
/// ucunda GECERSIZ — sunucu tarafinda testle kilitli.
///
/// =========================================================================
/// %27 — TELEFONSUZ KULLANICI KENAR DURUM DEGIL
/// =========================================================================
/// Olculdu: Yonetiyor'daki 3104 kullanicinin 837'sinde (%27) telefon YOK.
/// Kopru bu durumda 409 `telefon_gerekli` doner. Bu bir HATA EKRANI gibi
/// degil, akisin NORMAL bir dali gibi ele alinmali: kullanici telefon-OTP
/// akisina yonlendirilir.
///
/// F4'te mobilde OTP akisi HENUZ YOK; bu durumda kullaniciya ne oldugu
/// ACIKCA soyleniyor ve web'e yonlendiriliyor. Sessizce bos bir ekran
/// gostermek, her dort kullanicidan birini akisin ortasinda birakirdi.
class DukkanOturumHatasi implements Exception {
  DukkanOturumHatasi(this.kod);

  /// 'telefon_gerekli' | 'yonetiyor_jetonu_gecersiz' | 'hesap_askida' | 'ag'
  final String kod;

  @override
  String toString() => 'DukkanOturumHatasi($kod)';
}

class DukkanOturum {
  DukkanOturum(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  String? _jeton;

  String? get jeton => _jeton;

  /// Yonetiyor oturumuyla Dukkan jetonu alir. Doner: jeton.
  ///
  /// Hata halinde `DukkanOturumHatasi` firlatir — sessizce `null`
  /// dondurmek, cagiranin "jeton yok mu, hata mi" ayrimini yapamamasi
  /// demekti.
  Future<String> jetonAl() async {
    final mevcut = _jeton;
    if (mevcut != null) return mevcut;

    // ==================================================================
    // (F7 §2) ONCE CIHAZDAKI JETON — KOPRU SONRA
    // ==================================================================
    // Sira onemli: kopru once denenseydi, telefonu OLMAYAN kullanici
    // (olculdu: %27) OTP ile jeton almis olsa bile her acilista yine
    // 409 alir ve YENIDEN OTP'ye sokulurdu. Yani OTP akisi her gun bir
    // SMS demek olurdu ve kullanilamazdi.
    //
    // Depo, jetonu Yonetiyor kullanicisina BAGLI tutuyor; baskasinin
    // jetonu okunmaz (bkz. dukkan_jeton_deposu.dart).
    final saklanan = await _ref.read(dukkanJetonDeposuProvider).oku();
    if (saklanan != null) {
      _jeton = saklanan;
      unawaited(_ref.read(dukkanPushKaydiProvider).kaydet(saklanan));
      return saklanan;
    }

    try {
      // `dio` Yonetiyor jetonunu `auth_interceptor` ile zaten ekliyor;
      // kopru o jetonu okuyup Dukkan jetonu uretiyor.
      final r = await _dio.post<Map<String, dynamic>>('/dukkan/auth/yonetiyor');
      final j = r.data?['access_token'] as String?;
      if (j == null) throw DukkanOturumHatasi('yanit_bos');
      _jeton = j;
      unawaited(_ref.read(dukkanJetonDeposuProvider).yaz(j));
      // (F6-ek) CIHAZI DUKKAN'A KAYDET — jeton ALINDIGI AN.
      //
      // `unawaited` degil, `await` DE DEGIL: kayit bilerek beklenmeden
      // baslatiliyor. Beklemek, kullanicinin acmak istedigi ekrani bir ag
      // gidis-donusu kadar geciktirirdi; kayit ise gecikse de calisir.
      // Fonksiyon hicbir kosulda firlatmiyor (bkz. dukkan_push.dart).
      unawaited(_ref.read(dukkanPushKaydiProvider).kaydet(j));
      return j;
    } on DioException catch (e) {
      final kod = (e.response?.data is Map)
          ? '${(e.response!.data as Map)['error']?['code'] ?? ''}'
          : '';
      if (e.response?.statusCode == 409) {
        throw DukkanOturumHatasi('telefon_gerekli');
      }
      if (e.response?.statusCode == 403) {
        throw DukkanOturumHatasi('hesap_askida');
      }
      if (e.response?.statusCode == 401) {
        throw DukkanOturumHatasi('yonetiyor_jetonu_gecersiz');
      }
      throw DukkanOturumHatasi(kod.isEmpty ? 'ag' : kod);
    }
  }

  /// Cikista: cihaz kaydini DA dusurur.
  ///
  /// Yalniz `_jeton = null` demek yetmezdi — sunucudaki cihaz satiri
  /// kalirdi ve telefonda oturum acan bir sonraki kisi onceki
  /// kullanicinin teklif bildirimlerini gorurdu.
  void temizle() {
    final j = _jeton;
    _jeton = null;
    // KALICI KAYIT DA SILINIYOR: yalniz bellegi temizlemek, cikis sonrasi
    // ayni cihazda giren kisinin depodaki jetonu okumasini engellemezdi.
    unawaited(_ref.read(dukkanJetonDeposuProvider).sil());
    if (j != null) unawaited(_ref.read(dukkanPushKaydiProvider).sil(j));
  }

  /// (F7 §2) OTP akisi bittiginde cagrilir: jetonu YERLESTIRIR.
  ///
  /// Kopru 409 `telefon_gerekli` dondugunde kullanici telefonunu Dukkan'da
  /// DOGRUDAN dogruluyor ve buradan devam ediyor. Yonetiyor'a telefon
  /// YAZILMIYOR — kopru salt okunur ve bu sinir testle kilitli; Dukkan'in
  /// Yonetiyor'a yazmasi bir sinir ihlali olurdu.
  ///
  /// Bunun bedeli: OTP ile acilan hesapta `dukkan_yonetiyor_bag` satiri
  /// YOK. Yani ayni kisi web'de Yonetiyor SSO'suyla girerse, telefonu
  /// AYNIYSA ayni Dukkan hesabina duser (`dukkan_kullanici.telefon`
  /// UNIQUE); degilse ayri bir hesabi olur. Bu, telefonu Yonetiyor'da
  /// olmayan bir kullanici icin kacinilmaz.
  Future<void> jetonKur(String jeton) async {
    _jeton = jeton;
    await _ref.read(dukkanJetonDeposuProvider).yaz(jeton);
    unawaited(_ref.read(dukkanPushKaydiProvider).kaydet(jeton));
  }
}

final dukkanOturumProvider =
    Provider<DukkanOturum>((ref) => DukkanOturum(ref.watch(dioProvider), ref));
