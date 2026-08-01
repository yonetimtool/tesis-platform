// (P96) Arama YALNIZCA `tel:` semasini acar.
//
// `dial` metnine IKI yoldan girilir:
//   * `telUri()` — semayi kendi kurar, `^\+?\d+$` dogrular (guvenli),
//   * `call_models.dart` — `tel_uri` alanini SUNUCU JSON'undan alir ve
//     hicbir dogrulama yapmaz.
// Ikincisi dogrulanmiyordu: sunucu `https://…` ya da bir uygulama semasi
// dondurseydi `launchUrl` onu HARICI UYGULAMADA acardi — kullanici "Ara"
// dedigi icin tarayici acilir ve nedenini anlamazdi. Ayni eylemin iki
// yolu ayni guvene sahip olmali.
//
// KARAR `telSemasi` ile AYRI test edilir; `dial` uzerinden test etmek
// `launchUrl` -> MethodChannel yolunu tetikler ve baglam kurulu degilse
// testin konusu degil ORTAMI olculur (ilk yazimda tam bu oldu: dosya tek
// basina gecti, tam suitte dustu).
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';

void main() {
  test('tel DISI semalar REDDEDILIR', () {
    for (final kotu in [
      'https://ornek.test/phish',
      'http://ornek.test',
      'javascript:alert(1)',
      'intent://x#Intent;scheme=http;end',
      'file:///etc/passwd',
      'ornek.test',
      '',
      'tel:', // sema dogru ama aranacak numara YOK
    ]) {
      expect(telSemasi(kotu), isNull, reason: kotu);
    }
  });

  test('gecerli tel URI KABUL edilir', () {
    expect(telSemasi('tel:+905551112233')?.scheme, 'tel');
    expect(telSemasi('tel:05551112233')?.path, '05551112233');
  });
}
