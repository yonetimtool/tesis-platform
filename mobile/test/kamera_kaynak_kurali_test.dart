/// (P121) DESTEKLENEN KAYNAK KURALI — web sayfası adresleri REDDEDİLİR.
///
/// NEDEN SUNUCU DEĞİL İSTEMCİ: sunucunun şema kontrolü `https://` görüp
/// geçerli sayar ve saymalıdır da — `https://nvr.local/kanal.m3u8` ile
/// `https://youtube.com/watch?v=…` şema açısından ayırt edilemez. Ama
/// oynatıcı `video_player`dır ve **doğrudan medya akışı** bekler; bir HTML
/// sayfasını oynatamaz.
///
/// Kural konmazsa belirti şudur: yönetici adresi yapıştırır, kayıt
/// **başarılı** olur, kamera listede görünür ve dokununca açılmaz. Teşhis
/// kamerada aranır — oysa hata **kayıttadır**. Bu, tam olarak bu turda
/// kamera oynatma tarafında iki tur kaybettiren sınıfın aynısıdır.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';

void main() {
  group('webSayfasiMi', () {
    for (final u in [
      'https://www.youtube.com/watch?v=abc123',
      'https://youtu.be/abc123',
      'https://player.vimeo.com/video/123',
      'https://vimeo.com/123456',
      'https://www.twitch.tv/kanal',
      'https://www.facebook.com/site/videos/1',
    ]) {
      test('REDDEDER: $u', () {
        expect(CameraDraft.webSayfasiMi(u), isTrue);
        expect(CameraDraft.urlHatasi(u, CameraTur.hls),
            CameraUrlHatasi.webSayfasi);
      });
    }

    for (final u in [
      'https://nvr.example.com/hls/1/index.m3u8',
      'https://cdn.example.com/kayit/1.mp4',
      'http://frigate.local:5000/api/kapi/stream.m3u8',
      // Sorgu dizesi ATILIR: imzali jeton tasiyan bir HLS adresi gecerlidir.
      'https://gecit.example/hls/1.m3u8?token=abc',
    ]) {
      test('KABUL EDER: $u', () {
        expect(CameraDraft.webSayfasiMi(u), isFalse);
        expect(CameraDraft.urlHatasi(u, CameraTur.hls), isNull);
      });
    }

    test('BILINEN BARINDIRICIDA BILE dogrudan medya adresi KABUL edilir', () {
      // Kural "alan adi kara listesi" degil: bir gun youtube.com bir .m3u8
      // sunarsa onu reddetmek YANLIS olurdu. Olculen sey ADRESIN NE
      // DONDURDUGU; uzanti varsa karar uzantinindir.
      expect(
        CameraDraft.webSayfasiMi('https://www.youtube.com/canli/akis.m3u8'),
        isFalse,
      );
    });

    test('rtsp adresi bu kuraldan ETKILENMEZ', () {
      // `rtsp://` zaten ayri bir yoldan degerlendirilir; burada "web sayfasi"
      // diye isaretlemek yanlis teshis olurdu.
      expect(CameraDraft.webSayfasiMi('rtsp://10.0.0.7:554/kanal1'), isFalse);
      expect(CameraDraft.urlHatasi('rtsp://10.0.0.7:554/k', CameraTur.rtsp),
          isNull);
    });

    test('BOZUK adres cokmez', () {
      expect(CameraDraft.webSayfasiMi('http://'), isFalse);
      expect(CameraDraft.webSayfasiMi('bozuk'), isFalse);
      expect(CameraDraft.webSayfasiMi(''), isFalse);
    });
  });

  group('snapshotHatasi (P121)', () {
    test('BOS gecerli — alan istege baglidir', () {
      expect(CameraDraft.snapshotHatasi(''), isNull);
      expect(CameraDraft.snapshotHatasi(null), isNull);
      expect(CameraDraft.snapshotHatasi('   '), isNull);
    });

    test('http(s) KABUL', () {
      expect(
        CameraDraft.snapshotHatasi('http://frigate.local:5000/api/k/latest.jpg'),
        isNull,
      );
    });

    test('rtsp REDDEDILIR — kare adresi bir GORSEL adresidir', () {
      // Sunucudaki `dogrula_snapshot` ile ayni kural: istemci ONCE yakalar
      // ki kullanici gonderip 422 beklemesin.
      expect(
        CameraDraft.snapshotHatasi('rtsp://10.0.0.7:554/k.jpg'),
        CameraUrlHatasi.httpSemasiGerekli,
      );
    });

    test('WEB SAYFASI REDDEDILIR', () {
      expect(
        CameraDraft.snapshotHatasi('https://www.youtube.com/watch?v=a'),
        CameraUrlHatasi.webSayfasi,
      );
    });

    test('UZUNLUK siniri bu alanda da gecerli', () {
      expect(
        CameraDraft.snapshotHatasi('https://o/${'a' * kCameraUrlUstSinir}'),
        CameraUrlHatasi.cokUzun,
      );
    });
  });

  group('gonderilen govde', () {
    test('BOS kare adresi OLUSTURMA govdesine HIC yazilmaz', () {
      final d = CameraDraft(
        ad: 'K', streamUrl: 'https://o/x.m3u8', tur: CameraTur.hls,
        aktif: true, sakinGorebilir: false, snapshotUrl: '',
      );
      expect(d.toCreateJson().containsKey('snapshot_url'), isFalse);
    });

    test('BOS kare adresi GUNCELLEMEDE ACIK null gider (kaldirma)', () {
      // Sunucu sozlesmesi: acik null alani temizler. Alani hic gondermemek
      // "degistirme" demek olurdu ve kullanici kutuyu bosaltinca kare
      // adresi KALIRDI.
      final d = CameraDraft(
        ad: 'K', streamUrl: 'https://o/x.m3u8', tur: CameraTur.hls,
        aktif: true, sakinGorebilir: false, snapshotUrl: '',
      );
      expect(d.toUpdateJson()['snapshot_url'], isNull);
      expect(d.toUpdateJson().containsKey('snapshot_url'), isTrue);
    });

    test('DOLU kare adresi iki govdede de gider', () {
      const u = 'http://frigate.local:5000/api/k/latest.jpg';
      final d = CameraDraft(
        ad: 'K', streamUrl: 'https://o/x.m3u8', tur: CameraTur.hls,
        aktif: true, sakinGorebilir: false, snapshotUrl: u,
      );
      expect(d.toCreateJson()['snapshot_url'], u);
      expect(d.toUpdateJson()['snapshot_url'], u);
    });
  });

  group('Camera.fromJson', () {
    test('snapshot_url okunur ve kareCekilebilir olur', () {
      final c = Camera.fromJson({
        'id': '1', 'ad': 'K', 'stream_url': 'https://o/x.m3u8',
        'snapshot_url': 'http://a/b.jpg',
      });
      expect(c.snapshotUrl, 'http://a/b.jpg');
      expect(c.kareCekilebilir, isTrue);
    });

    test('ALAN YOKSA (eski sunucu) kare cekilmez — davranis degismez', () {
      final c = Camera.fromJson({
        'id': '1', 'ad': 'K', 'stream_url': 'https://o/x.m3u8',
      });
      expect(c.snapshotUrl, isNull);
      expect(c.kareCekilebilir, isFalse);
    });
  });
}
