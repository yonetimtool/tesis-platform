/// CİHAZ TEŞHİSİ — "kaynakta ne yazıyor" değil, **pakette ne var**.
///
/// NEDEN VAR: iki iOS hatası (kamera yayını açılmıyor, NFC "Missing
/// required entitlement") üst üste **körlemesine** düzeltilmeye çalışıldı
/// ve ikisi de cihazda düşmeye devam etti. Ortak sebep teşhis eksikliği
/// değil, **kanıt** eksikliğiydi:
///
///   * Ekrandaki ham hata metni YALNIZ hata ayıklama yapımında
///     gösteriliyordu; TestFlight bir **yayın** yapımıdır — Kerem'in
///     gördüğü tek şey "yayın açılamadı" cümlesiydi.
///   * NFC tarafında eklenti oturum hatasının **kodunu** veriyor
///     (`NfcReaderErrorCodeIos`), bizim kod ise yalnız `message`i alıp
///     hepsini `okumaIptal` diye etiketliyordu. Yani cihazdaki
///     "Missing required entitlement" ekrana **"Okuma iptal edildi"**
///     diye çıkıyordu — hata sınıfı yanlış adlandırılmıştı.
///   * `Info.plist`in KAYNAKTA doğru olması, o anahtarın **yapıya
///     girdiğini** kanıtlamaz (`GENERATE_INFOPLIST_FILE`, hedef
///     karışması, yanlış `INFOPLIST_FILE`). Tek kesin ölçüm, çalışan
///     paketin kendi sözlüğünü okumaktır — [iosPaketGercekleri] bunu
///     yapar.
///
/// GÜNLÜK `debugPrint` iledir (yayın yapımında da çalışır); `dart:developer`
/// tercih edilmedi çünkü AOT yayın yapımında VM servisi yoksa düşer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native teşhis kanalı (yalnız iOS; `ios/Runner/AppDelegate.swift`).
@visibleForTesting
const teshisKanali = MethodChannel('site.yonetio.app/teshis');

/// Tek satırlık teşhis kaydı. Ekranda değil KONSOLDA görünür.
void teshisYaz(String alan, String mesaj) => debugPrint('[$alan] $mesaj');

/// Adresi günlüğe yazılabilir hâle getirir.
///
/// KİMLİK BİLGİSİ ATILIR: saha kameralarının adresleri gerçek dünyada
/// `rtsp://kullanici:parola@10.0.0.5/...` biçimindedir. Teşhis günlüğü
/// ekran görüntüsüyle paylaşılır, hata kaydına yapıştırılır — parolayı
/// oraya yazmak, teşhis uğruna kalıcı bir sızıntı açmaktır. Konak ve yol
/// KORUNUR: teşhisi yapan şey zaten onlardır.
///
/// SORGU DİZESİ de atılır (imzalı jeton/`token=` taşır) ama VARLIĞI
/// bildirilir — "adres sorgu taşıyor mu" sorusu bazen tek ayırt edici
/// bilgidir.
String adresMaskele(String url) {
  final temiz = url.trim();
  if (temiz.isEmpty) return '(bos)';
  // IC BOSLUK/SATIR SONU: yapistirma artigi. `Uri.tryParse` bunu HOSGORUR
  // (boslugu `%20` yapip yola koyar) ve adres "cozuldu" gibi gorunur —
  // maskeleme de o zaman gecerli bir adresmis gibi yol/konak yazardi.
  // Ayni kural oynaticida da uygulaniyor (`adresOynatilabilirMi`); oradan
  // CAGRILMIYOR cunku bu dosya `core/`dedir ve bir ozellik klasorune
  // (features/cameras) bagimli olamaz.
  final uri = RegExp(r'\s').hasMatch(temiz) ? null : Uri.tryParse(temiz);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    // Çözülemeyen adres: UZUNLUĞU bildirilir (görünmez karakter/boşluk
    // teşhisi için), içeriği YAZILMAZ.
    return '(cozulemedi, ${temiz.length} karakter)';
  }
  final kimlik = uri.userInfo.isEmpty ? '' : '***@';
  final port = uri.hasPort ? ':${uri.port}' : '';
  final sorgu = uri.query.isEmpty ? '' : ' +sorgu(${uri.query.length})';
  return '${uri.scheme}://$kimlik${uri.host}$port${uri.path}$sorgu';
}

/// Çalışan iOS paketinin gerçekleri. Android'de / testte `null` döner.
///
/// Anahtarlar `AppDelegate.swift` ile birebir; okunan yer **çalışan
/// paketin** `Info.plist`idir, depodaki dosya DEĞİL.
Future<Map<String, Object?>?> iosPaketGercekleri() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return null;
  try {
    final sonuc = await teshisKanali.invokeMapMethod<String, Object?>(
      'paketGercekleri',
    );
    return sonuc;
  } on PlatformException catch (e) {
    teshisYaz('TESHIS', 'paket gercekleri okunamadi: ${e.code} ${e.message}');
    return null;
  } on MissingPluginException {
    // Kanal yok: eski bir yapım ya da hedefe girmemiş AppDelegate.
    teshisYaz('TESHIS', 'kanal YOK — AppDelegate teshis kanali derlenmemis');
    return null;
  }
}

/// Yayın oynatıcısının teşhis kayıtları.
///
/// METİNLER BURADA, EKRANDA DEĞİL: `presentation/` altındaki sabit metin
/// taraması, çizim katmanına yazılmış her dizgeyi (haklı olarak) çeviri
/// kaçağı sayar. Teşhis satırları çevrilmez — bu yüzden çizim katmanının
/// DIŞINDA durur ve ekran yalnızca çağırır.
class YayinTeshis {
  const YayinTeshis._();

  /// Oynatıcı açılırken: kameranın KİMLİĞİ ve gerçekten kullanılan adres.
  ///
  /// Bu satır tek başına bir soruyu kapatır: "Android'de çalışan yayınla
  /// iOS'ta açılmayan yayın AYNI adres mi?" İki platform farklı tesise /
  /// farklı kayda bakıyorsa (biri tohumlanmış genel HLS, öteki sahadaki
  /// yerel ağ kamerası) ortada iOS hatası yoktur.
  static void acildi({
    required String ad,
    required String tur,
    required bool oynatilabilir,
    required String streamUrl,
    required String? restreamUrl,
    required String secilenUrl,
  }) {
    teshisYaz('YAYIN', 'kamera="$ad" tur=$tur oynatilabilir=$oynatilabilir');
    teshisYaz('YAYIN', 'stream   = ${adresMaskele(streamUrl)}');
    teshisYaz('YAYIN', 'restream = ${restreamUrl == null ? "YOK" : adresMaskele(restreamUrl)}');
    teshisYaz('YAYIN', 'SECILEN  = ${adresMaskele(secilenUrl)}');
  }

  /// `initialize()` çağrıldı — saat başlatıldı.
  static void hazirlaniyor() => teshisYaz('YAYIN', 'initialize() basladi');

  /// `initialize()` döndü: boyut/süre, oynatıcının gerçekten kurulduğunu
  /// gösterir. Boyut 0x0 ise ses var görüntü yok demektir (kodek reddi).
  static void hazir(Duration gecen, String boyut) =>
      teshisYaz('YAYIN', 'HAZIR ${gecen.inMilliseconds}ms boyut=$boyut');

  /// `initialize()` düştü ya da zaman aşımına uğradı — HAM platform metni.
  static void dustu(Duration gecen, Object hata) =>
      teshisYaz('YAYIN', 'DUSTU ${gecen.inMilliseconds}ms -> $hata');

  /// Hazırlık SONRASI hata (varyant/parça/kodek reddi). AVPlayer'ın tipik
  /// başarısızlığı budur ve `initialize()`in Future'ına HİÇ yansımaz.
  static void sonradanHata(String? mesaj) =>
      teshisYaz('YAYIN', 'HAZIRLIK SONRASI HATA -> ${mesaj ?? "(mesaj yok)"}');
}

/// Açılışta TEK bir blok yazar. Kerem'in `flutter run` çıktısından
/// kopyalayacağı bölüm budur.
Future<void> teshisBlogunuYazdir() async {
  final g = await iosPaketGercekleri();
  if (g == null) return;
  String d(String anahtar) {
    final v = g[anahtar];
    if (v == null) return 'YOK';
    if (v is List) return v.isEmpty ? 'BOS LISTE' : v.join(',');
    return '$v';
  }

  teshisYaz('TESHIS', '=== PAKET GERCEKLERI (calisan yapim) ===');
  teshisYaz('TESHIS', 'paket      : ${d('paket')} ${d('surum')}(${d('yapim')})');
  teshisYaz('TESHIS', 'ats.sozluk : ${d('atsVar')}');
  teshisYaz('TESHIS', 'ats.medya  : ${d('atsMedya')}');
  teshisYaz('TESHIS', 'ats.keyfi  : ${d('atsKeyfi')}');
  teshisYaz('TESHIS', 'nfc.aciklama: ${d('nfcAciklama')}');
  teshisYaz('TESHIS', 'nfc.aid    : ${d('nfcAid')}');
  teshisYaz('TESHIS', 'nfc.felica : ${d('nfcFelica')}');
  teshisYaz('TESHIS', '=== /PAKET GERCEKLERI ===');
}
