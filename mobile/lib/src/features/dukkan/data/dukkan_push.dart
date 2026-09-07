import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../push/presentation/push_registrar.dart';
import 'dukkan_api.dart';

/// (DUKKAN F6-ek) DUKKAN FCM KAYDI.
///
/// ===========================================================================
/// NE ZAMAN KAYIT YAPILIR: GIRISTE DEGIL, DUKKAN JETONU ALININCA
/// ===========================================================================
/// En kolay yol, Yonetiyor girisinden hemen sonra kopruyu cagirip cihazi
/// kaydetmekti. YAPILMADI, cunku kopru cagrisi Dukkan'da KULLANICI
/// OLUSTURUR: pazar yerini hic acmamis binlerce kisi icin hesap acmak
/// olurdu. Bu hem KVKK acisindan savunulamaz (kisi bir urune kaydolmadi)
/// hem de "kayitli kullanici" sayisini anlamsiz sisirirdi.
///
/// Bunun yerine kayit, kullanici DUKKAN JETONU ALDIGI AN yapilir — yani
/// pazar yerinin kimlik isteyen bir yuzeyini kendi actiginda. O noktada
/// hesap zaten olusuyor; cihazi eklemek ek bir sey acmiyor.
///
/// ===========================================================================
/// HATA YUTULUYOR AMA SESSIZ DEGIL
/// ===========================================================================
/// Kayit basarisiz olursa akis DURMAZ (kullanici talebini olusturmaya
/// devam edebilmeli) ama `debugPrint` ile iz birakir. P191'de olculen
/// tuzak buydu: bildirim gitmiyordu ve HICBIR YERDE yazmiyordu.
class DukkanPushKaydi {
  DukkanPushKaydi(this._ref);

  final Ref _ref;

  /// Ayni jetonu her ekran acilisinda tekrar gondermemek icin.
  /// Sunucu zaten idempotent (`ON CONFLICT`), bu yalniz gereksiz istegi
  /// engelliyor.
  String? _kayitli;

  /// Dukkan jetonu alindiktan SONRA cagrilir. Hicbir kosulda firlatmaz.
  Future<void> kaydet(String dukkanJetonu) async {
    try {
      final messaging = _ref.read(pushMessagingProvider);
      // Firebase kurulu degilse (google-services.json'siz build) burada
      // `false` doner ve kayit atlanir — uygulama normal calisir.
      if (!await messaging.initialize()) return;
      final token = await messaging.getToken();
      if (token == null || token == _kayitli) return;
      await _ref.read(dukkanApiProvider).cihazKaydet(
            fcmToken: token,
            platform:
                defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
            // DIL CIHAZ BASINA saklaniyor: ayni hesabin iki cihazi farkli
            // dilde olabilir ve bildirim CIHAZIN dilinde gitmeli.
            dil: _ref.read(aktifDilKoduProvider),
            jeton: dukkanJetonu,
          );
      _kayitli = token;
    } catch (e) {
      debugPrint('Dukkan push kaydi basarisiz (sonraki acilista denenir): $e');
    }
  }

  /// Cikista cihazi Dukkan tarafindan da dusurur.
  ///
  /// YONETIYOR CIKISI DUKKAN CIHAZINI DA DUSURMELI: ayni telefonda baska
  /// biri oturum acarsa, onceki kullanicinin teklif bildirimlerini
  /// GORURDU. Iki urunun cihaz kaydi ayri tablolarda oldugu icin bu
  /// dusme AYRICA yapilmali — biri digerini kapatmaz.
  Future<void> sil(String dukkanJetonu) async {
    try {
      final token = _kayitli;
      if (token == null) return;
      await _ref
          .read(dukkanApiProvider)
          .cihazSil(fcmToken: token, jeton: dukkanJetonu);
      _kayitli = null;
    } catch (e) {
      debugPrint('Dukkan cihaz kaydi silinemedi: $e');
    }
  }
}

final dukkanPushKaydiProvider =
    Provider<DukkanPushKaydi>((ref) => DukkanPushKaydi(ref));
