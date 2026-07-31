// P34 — okutma konumu ve fotograf kapisi: konum bir KANITTIR, ON KOSUL DEGIL.
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/src/features/scan/data/konum_servisi.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/scan/domain/scan.dart';

void main() {
  group('konum durumu eslemesi', () {
    test('servis kapali IZIN REDDI DEGILDIR', () {
      // Ikisini ayni saymak, kullaniciya "izin verin" demek olurdu — oysa
      // izin verili, kapali olan cihazin konum servisi.
      final s = konumEngeli(
          servisAcik: false, izin: LocationPermission.whileInUse);
      expect(s.durum, KonumDurumu.servisKapali);
    });

    test('KALICI ret de izin_yok sayilir', () {
      for (final izin in [
        LocationPermission.denied,
        LocationPermission.deniedForever,
      ]) {
        expect(konumEngeli(servisAcik: true, izin: izin).durum,
            KonumDurumu.izinYok);
      }
    });

    test('engel yoksa bilinmiyor doner (konum ayrica olculur)', () {
      expect(
        konumEngeli(servisAcik: true, izin: LocationPermission.always).durum,
        KonumDurumu.bilinmiyor,
      );
    });

    test('kod <-> enum cift yonlu ve BILINMEYEN kod bilinmiyor olur', () {
      for (final d in KonumDurumu.values) {
        expect(konumDurumuCoz(konumDurumuKodu[d]), d);
      }
      expect(konumDurumuCoz('uydurma'), KonumDurumu.bilinmiyor);
      expect(konumDurumuCoz(null), KonumDurumu.bilinmiyor);
    });
  });

  group('taslak govdesi', () {
    test('konum alanlari YALNIZ dolu ise govdeye girer', () {
      final bos = ScanDraft(
          nfcTagUid: 'A', okutmaZamani: DateTime.utc(2026, 7, 31)).toJson();
      expect(bos.containsKey('konum_durumu'), isFalse);
      expect(bos.containsKey('gps_dogruluk_m'), isFalse);
      expect(bos.containsKey('foto_key'), isFalse);

      final dolu = ScanDraft(
        nfcTagUid: 'A',
        okutmaZamani: DateTime.utc(2026, 7, 31),
        gpsLat: 41.0,
        gpsLng: 29.0,
        konumDurumu: 'var',
        gpsDogrulukM: 12.5,
        fotoKey: 't/x.jpg',
      ).toJson();
      expect(dolu['konum_durumu'], 'var');
      expect(dolu['gps_dogruluk_m'], 12.5);
      expect(dolu['foto_key'], 't/x.jpg');
    });

    test('IZIN YOK okutmayi DUSURMEZ: durum gider, koordinat gitmez', () {
      final j = ScanDraft(
        nfcTagUid: 'A',
        okutmaZamani: DateTime.utc(2026, 7, 31),
        konumDurumu: 'izin_yok',
      ).toJson();
      expect(j['konum_durumu'], 'izin_yok');
      expect(j.containsKey('gps_lat'), isFalse);
    });
  });

  group('kuyruk kaydi', () {
    ScanDraft taslak() => ScanDraft(
          nfcTagUid: 'A',
          okutmaZamani: DateTime.utc(2026, 7, 31),
          gpsLat: 41.0,
          gpsLng: 29.0,
          konumDurumu: 'var',
          gpsDogrulukM: 8.0,
        );

    test('konum DISKTE yasar — okutma ani ile gonderim ani ayridir', () {
      final e = OutboxEntry.fromDraft(taslak(), now: DateTime.utc(2026, 7, 31));
      final geri = OutboxEntry.fromJson(e.toJson());
      expect(geri.konumDurumu, 'var');
      expect(geri.gpsDogrulukM, 8.0);
      expect(geri.toDraft().toJson()['konum_durumu'], 'var');
    });

    test('fotograf SONRADAN eklenir, ANAHTAR DEGISMEZ', () {
      // Ilk deneme 422 ile reddedildi -> sunucuda kayit YOK; ayni anahtarla
      // fotografli govde gondermek cakisma degil ILK basarili gonderimdir.
      final e = OutboxEntry.fromDraft(taslak(), now: DateTime.utc(2026, 7, 31));
      final fotolu = e.copyWith(
          fotoKey: 't/foto.jpg', status: OutboxStatus.bekliyor);
      expect(fotolu.idempotencyKey, e.idempotencyKey);
      expect(fotolu.toDraft().toJson()['foto_key'], 't/foto.jpg');
      expect(OutboxEntry.fromJson(fotolu.toJson()).fotoKey, 't/foto.jpg');
    });

    test('fotografi olmayan kayit alani govdeye KOYMAZ', () {
      final e = OutboxEntry.fromDraft(taslak(), now: DateTime.utc(2026, 7, 31));
      expect(e.toJson().containsKey('foto_key'), isFalse);
      expect(e.copyWith(status: OutboxStatus.gonderildi).fotoKey, isNull);
    });
  });
}
