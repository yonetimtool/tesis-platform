/// P25 — kamera sertlestirme: (a) adres uzunluk siniri, (b) oynatma
/// hatalarinin NEDENE gore ayrilmasi, (c) ana ekran seridinin dortlu genisligi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/domain/yayin_hatasi.dart';
import 'package:mobile/src/features/cameras/presentation/yayin_hatasi_metni.dart';
import 'package:mobile/src/features/home/presentation/widgets/kamera_seridi.dart';

import 'helpers/l10n_test_app.dart';

String _uzun(int n) {
  const onek = 'https://ornek.test/';
  return onek + 'a' * (n - onek.length);
}

void main() {
  // ------------------------------------------------------------------ (a)
  group('P25a — adres uzunluk siniri', () {
    test('sunucuyla AYNI sayi (2048)', () {
      // Iki yerde durmasi bilincli ama SAYI ayni olmali; farkli olsaydi
      // istemci "gecerli" dedigi adresi gonderip 422 yerdi.
      expect(kCameraUrlUstSinir, 2048);
    });

    test('TAM sinir gecerli, bir fazlasi HATA', () {
      expect(CameraDraft.urlHatasi(_uzun(2048), CameraTur.hls), isNull);
      expect(
        CameraDraft.urlHatasi(_uzun(2049), CameraTur.hls),
        CameraUrlHatasi.cokUzun,
      );
    });

    test('uzunluk SEMADAN ONCE olculur', () {
      // 3 KB'lik bir yapistirmada "https ile baslamali" demek yaniltici
      // olurdu — adres zaten https ile BASLIYOR.
      expect(
        CameraDraft.urlHatasi(_uzun(3000), CameraTur.hls),
        CameraUrlHatasi.cokUzun,
      );
      // rtsp turunde de sema hatasi DEGIL uzunluk hatasi doner.
      expect(
        CameraDraft.urlHatasi(_uzun(3000), CameraTur.rtsp),
        CameraUrlHatasi.cokUzun,
      );
    });

    test('restream alani da sinirli, BOS hala serbest', () {
      expect(CameraDraft.restreamHatasi(''), isNull, reason: 'opsiyonel alan');
      expect(CameraDraft.restreamHatasi(_uzun(2048)), isNull);
      expect(
        CameraDraft.restreamHatasi(_uzun(2049)),
        CameraUrlHatasi.cokUzun,
      );
    });
  });

  // ------------------------------------------------------------------ (b)
  group('P25b — yayin hatasi NEDENI', () {
    test('bosluk/satir sonu tasiyan adres: adresBozuk', () {
      // ESKIDEN CAKILIYORDU: `Uri.parse` try blogunun DISINDAYDI.
      for (final k in ['', '   ', 'https://ornek /a.m3u8', 'sadece-metin']) {
        expect(yayinHatasiCoz(k, null), YayinHatasi.adresBozuk, reason: k);
      }
    });

    test('oynatilamaz semalar: semaDesteklenmiyor', () {
      for (final k in [
        'rtsp://10.0.0.5:554/s',
        'RTSP://10.0.0.5:554/s',
        'rtmp://ornek/live',
        'srt://ornek:9000',
      ]) {
        expect(
          yayinHatasiCoz(k, null),
          YayinHatasi.semaDesteklenmiyor,
          reason: k,
        );
      }
    });

    test('http + platform cleartext izi: sifrelenmemisEngellendi', () {
      expect(
        yayinHatasiCoz(
          'http://kamera.local/s.m3u8',
          Exception('CLEARTEXT communication to kamera.local not permitted'),
        ),
        YayinHatasi.sifrelenmemisEngellendi,
      );
      expect(
        yayinHatasiCoz(
          'http://kamera.local/s.m3u8',
          Exception('App Transport Security policy requires a secure connection'),
        ),
        YayinHatasi.sifrelenmemisEngellendi,
      );
    });

    test('http ama BASKA bir hata: ulasilamadi (yanlis teshis YOK)', () {
      expect(
        yayinHatasiCoz('http://kamera.local/s.m3u8', Exception('timeout')),
        YayinHatasi.ulasilamadi,
      );
    });

    test('https + ag hatasi: ulasilamadi', () {
      expect(
        yayinHatasiCoz('https://kamera.local/s.m3u8', Exception('404')),
        YayinHatasi.ulasilamadi,
      );
    });

    testWidgets('her neden 7 dilde BOS DEGIL, TR sizmaz ve AYRI metin verir',
        (tester) async {
      const trHarf = 'ğışĞİŞ';
      for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          l10nApp(
            Builder(
              builder: (ctx) {
                l10n = ctx.l10n;
                return const SizedBox.shrink();
              },
            ),
            locale: Locale(dil),
          ),
        );
        await tester.pumpAndSettle();
        final metinler = <String>{};
        for (final neden in YayinHatasi.values) {
          final m = yayinHatasiMetni(l10n, neden);
          expect(m.trim(), isNotEmpty, reason: '$dil/$neden');
          if (dil != 'tr') {
            expect(
              m.split('').any(trHarf.contains),
              isFalse,
              reason: '$dil/$neden TR harfi: $m',
            );
          }
          metinler.add(m);
        }
        // Dort neden DORT AYRI cumle olmali; ayni cumle, ayrimin kendisini
        // anlamsiz kilardi (P25'in cozdugu sorun buydu).
        expect(
          metinler.length,
          YayinHatasi.values.length,
          reason: '$dil: nedenler ayni metni paylasiyor',
        );
      }
    });
  });

  // ------------------------------------------------------------------ (c)
  group('P25c — ana ekran seridi DORTLU', () {
    Future<double> genislik(WidgetTester tester, double ekran) async {
      late double sonuc;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(ekran, 800)),
          child: l10nApp(
            Builder(
              builder: (ctx) {
                sonuc = kameraKartGenisligi(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sonuc;
    }

    testWidgets('tipik telefonda DORT kart sigar (eskiden iki)', (tester) async {
      const ekran = 400.0;
      final w = await genislik(tester, ekran);
      // Dordu + araliklari + kenar bosluklari ekrana SIGMALI.
      final toplam = 4 * w + 3 * 12 + 2 * 16;
      expect(toplam, lessThanOrEqualTo(ekran + 0.5));
      // Eski sabit genislik 168'di ve ekrana ikisi sigiyordu.
      expect(w, lessThan(168));
    });

    testWidgets('cok dar ekranda ALT SINIR korunur (okunmaz kart yok)',
        (tester) async {
      expect(await genislik(tester, 280), 80.0);
    });

    testWidgets('genis tablette UST SINIR korunur (kartlar devlesmez)',
        (tester) async {
      expect(await genislik(tester, 1200), 168.0);
    });

    testWidgets('yukseklik GENISLIGE bagli (sabit degil)', (tester) async {
      late double dar;
      late double genis;
      await tester.pumpWidget(
        l10nApp(
          Builder(
            builder: (ctx) {
              dar = kameraSeritYuksekligi(ctx, 80);
              genis = kameraSeritYuksekligi(ctx, 168);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(genis, greaterThan(dar));
    });
  });
}
