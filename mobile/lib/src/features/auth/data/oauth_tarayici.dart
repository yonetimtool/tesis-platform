import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// (P154 / Asama 4) SOSYAL GIRIS TARAYICI OTURUMU.
///
/// Saglayici sayfasi UYGULAMA ICI GUVENLI TARAYICIDA acilir
/// (Android: Custom Tabs, iOS: `ASWebAuthenticationSession`) ve akis
/// bittiginde ozel semaya donen adres yakalanir.
///
/// NEDEN WEBVIEW DEGIL: Google, gomulu WebView'de OAuth'u REDDEDER
/// ("disallowed_useragent") ve haklidir — gomulu bir gorunumde
/// kullanicinin adres cubugunu goremedigi bir parola ekrani gosterilir.
/// Guvenli tarayici oturumu ayrica kullanicinin MEVCUT saglayici
/// oturumunu kullanabilir; bir kez daha parola sormaz.
///
/// NEDEN YEREL SDK DEGIL: gerekce `auth_api.dart`ta — ozetle Apple
/// geri donusu icin https zorunlu, ve dogrulamanin TEK yerde (arka uc)
/// kalmasi gerekiyor.
///
/// SONUC JETON DEGIL, TEK KULLANIMLIK BIR KIMLIKTIR (`?oauth=<id>`).
/// Erisim jetonunu bir yonlendirme adresinde tasimak, onu tarayici
/// gecmisine ve sistem gunluklerine yazmak olurdu.
abstract class OauthTarayici {
  /// [adres]e gider, `SEMA://...?oauth=<id>` donusunu bekler ve `<id>`
  /// degerini verir. Kullanici vazgecerse `null` doner.
  Future<String?> akisiCalistir(String adres);
}

/// Ozel sema — arka uctaki `oauth_mobil_donus` ile AYNI olmali.
/// Ikisi ayrisirsa tarayici oturumu HIC kapanmaz ve kullanici bos bir
/// sayfada kalir; bu yuzden `test/oauth_test.dart` degeri kilitler.
const String kOauthSemasi = 'com.app.yonetiyor';

class OauthTarayiciImpl implements OauthTarayici {
  const OauthTarayiciImpl();

  @override
  Future<String?> akisiCalistir(String adres) async {
    try {
      final donus = await FlutterWebAuth2.authenticate(
        url: adres,
        callbackUrlScheme: kOauthSemasi,
      );
      return Uri.parse(donus).queryParameters['oauth'];
    } catch (_) {
      // VAZGECME HATA DEGILDIR: kullanici tarayiciyi kapattiginda paket
      // firlatir. Ekranda kirmizi bir hata gostermek, bilincli bir
      // vazgecisi arizaya benzetirdi.
      return null;
    }
  }
}

final oauthTarayiciProvider = Provider<OauthTarayici>(
  (ref) => const OauthTarayiciImpl(),
);
