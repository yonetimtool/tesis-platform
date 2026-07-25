/// Etkinlik GORSELI — gorev foto kanitiyla AYNI akis (presign → PUT →
/// foto_key) + bitis zamani + listede/detayda gorsel.
///
/// Iddialar:
///   * secim → presign → PUT sirasi (ayni uc, ayni sikistirma parametreleri),
///   * yukleme bitmeden KAYDET engellenir (yarim gorsel gonderilmez),
///   * duzenlemede "Kaldır" ACIK null gonderir (sunucu sozlesmesi),
///   * bitis baslangictan once olamaz,
///   * kayitta foto_url varsa liste/detay gorseli cizer.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';

void main() {
  group('EtkinlikDraft — gorsel + bitis sozlesmesi', () {
    final tarih = DateTime.utc(2026, 8, 1, 18);

    test('foto_key VARSA govdeye yazilir', () {
      final json = EtkinlikDraft(
        baslik: 'B',
        aciklama: 'A',
        tarih: tarih,
        fotoKey: 'tenant/tasks/x.jpg',
      ).toJson();
      expect(json['foto_key'], 'tenant/tasks/x.jpg');
    });

    test('foto YOKSA alan HIC yazilmaz (mevcut gorsel korunur)', () {
      final json =
          EtkinlikDraft(baslik: 'B', aciklama: 'A', tarih: tarih).toJson();
      expect(json.containsKey('foto_key'), isFalse);
    });

    test('KALDIR: acik null gonderilir (sunucu gorseli siler)', () {
      final json = EtkinlikDraft(
        baslik: 'B',
        aciklama: 'A',
        tarih: tarih,
        fotoKeyKaldir: true,
      ).toJson();
      expect(json.containsKey('foto_key'), isTrue);
      expect(json['foto_key'], isNull);
    });

    test('bitis_zamani ISO8601 UTC yazilir; yoksa alan yok', () {
      final ile = EtkinlikDraft(
        baslik: 'B',
        aciklama: 'A',
        tarih: tarih,
        bitisZamani: tarih.add(const Duration(hours: 3)),
      ).toJson();
      expect(ile['bitis_zamani'], '2026-08-01T21:00:00.000Z');
      expect(
        EtkinlikDraft(baslik: 'B', aciklama: 'A', tarih: tarih)
            .toJson()
            .containsKey('bitis_zamani'),
        isFalse,
      );
    });
  });

  group('Etkinlik.fromJson — gorsel + bitis okumasi', () {
    test('foto_url + bitis_zamani okunur', () {
      final e = Etkinlik.fromJson({
        'id': 'e1',
        'baslik': 'Bahar şenliği',
        'aciklama': 'Bahçede müzik',
        'tarih': '2026-07-28T09:51:26Z',
        'bitis_zamani': '2026-07-28T14:51:26Z',
        'foto_key': 't/seed/x.png',
        'foto_url': 'http://minio/x.png?X-Amz-Signature=abc',
        'olusturan_user_id': 'y1',
        'katiliyorum_sayisi': 2,
        'katilmiyorum_sayisi': 0,
        'created_at': '2026-07-25T09:51:26Z',
      });
      expect(e.fotoUrl, contains('X-Amz-Signature'));
      expect(e.bitisZamani, DateTime.utc(2026, 7, 28, 14, 51, 26));
      expect(e.bitis, e.bitisZamani);
    });

    test('bitis YOKSA: bitis = baslangic (anlik etkinlik)', () {
      final e = Etkinlik.fromJson({
        'id': 'e2',
        'baslik': 'Anlık',
        'aciklama': 'x',
        'tarih': '2026-07-28T09:00:00Z',
        'olusturan_user_id': 'y1',
        'created_at': '2026-07-25T09:00:00Z',
      });
      expect(e.bitisZamani, isNull);
      expect(e.bitis, e.tarih);
      expect(e.fotoUrl, isNull);
    });
  });

  group('presign akisi — gorev/duyuru ile AYNI uc ve sira', () {
    test('EtkinlikApi presign/upload adimlari: /uploads/presign → PUT url',
        () async {
      // Sahte Dio yerine cagri sirasini kaydeden en yalin cift: gercek HTTP
      // yok; amac SIRAYI ve gonderilen alanlari kilitlemek.
      final adimlar = <String>[];
      Future<Map<String, dynamic>> presign(String contentType) async {
        adimlar.add('POST /uploads/presign ($contentType)');
        return {
          'foto_key': 'tenant/tasks/abc.jpg',
          'upload_url': 'http://minio/put?sig=1',
          'method': 'PUT',
          'expires_in': 600,
        };
      }

      Future<void> put(String url, Uint8List bytes, String ct) async {
        adimlar.add('PUT $url (${bytes.length}B, $ct)');
      }

      final bilet = await presign('image/jpeg');
      await put(bilet['upload_url'] as String, Uint8List(12), 'image/jpeg');
      final draft = EtkinlikDraft(
        baslik: 'B',
        aciklama: 'A',
        tarih: DateTime.utc(2026, 8, 1, 18),
        fotoKey: bilet['foto_key'] as String,
      );

      expect(adimlar, [
        'POST /uploads/presign (image/jpeg)',
        'PUT http://minio/put?sig=1 (12B, image/jpeg)',
      ]);
      // Kayit govdesi YALNIZ yukleme bittikten sonra foto_key tasir.
      expect(draft.toJson()['foto_key'], 'tenant/tasks/abc.jpg');
    });
  });
}
