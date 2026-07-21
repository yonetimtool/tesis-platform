import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';

void main() {
  group('talepDurumFromWire / TalepDurumWire.wire', () {
    test('bilinen degerler cift yonlu eslesir', () {
      expect(talepDurumFromWire('acik'), TalepDurum.acik);
      expect(talepDurumFromWire('is_emri'), TalepDurum.isEmri);
      expect(talepDurumFromWire('cozuldu'), TalepDurum.cozuldu);
      expect(talepDurumFromWire('reddedildi'), TalepDurum.reddedildi);
      expect(TalepDurum.acik.wire, 'acik');
      expect(TalepDurum.isEmri.wire, 'is_emri');
      expect(TalepDurum.cozuldu.wire, 'cozuldu');
      expect(TalepDurum.reddedildi.wire, 'reddedildi');
    });

    test('bilinmeyen/null → unknown (ileriye uyumlu, parse hatasi yok)', () {
      expect(talepDurumFromWire('kapandi'), TalepDurum.unknown);
      expect(talepDurumFromWire(null), TalepDurum.unknown);
      // unknown ASLA sunucuya yazilmaz — bos tel.
      expect(TalepDurum.unknown.wire, '');
    });
  });

  group('TalepOncelik.wire (ASCII: dusuk|orta|yuksek)', () {
    test('tel degerleri ASCII', () {
      expect(TalepOncelik.dusuk.wire, 'dusuk');
      expect(TalepOncelik.orta.wire, 'orta');
      expect(TalepOncelik.yuksek.wire, 'yuksek');
    });
  });

  group('Complaint.fromJson', () {
    test('tam govde eslenir (fotograflar + gecmis + bagli is emri)', () {
      final c = Complaint.fromJson(const {
        'id': 'c-1',
        'acan_user_id': 'u-1',
        'acan_ad': 'Acme Sakin',
        'baslik': 'Asansor arizali',
        'mesaj': 'A blok asansoru durdu.',
        'kategori_id': 'k-1',
        'kategori_ad': 'Arıza',
        'durum': 'is_emri',
        'is_emri_id': 't-9',
        'is_emri_durum': 'acik',
        'fotograflar': [
          {
            'id': 'f-2',
            'foto_key': 't1/complaints/b.jpg',
            'sira': 1,
            'foto_url': 'http://minio.local/b.jpg?X-Amz-Signature=s2',
          },
          {
            'id': 'f-1',
            'foto_key': 't1/complaints/a.jpg',
            'sira': 0,
            'foto_url': 'http://minio.local/a.jpg?X-Amz-Signature=s1',
          },
        ],
        'gecmis': [
          {
            'durum': 'acik',
            'actor_role': 'resident',
            'created_at': '2026-07-09T10:00:00Z',
          },
          {
            'durum': 'is_emri',
            'actor_role': 'yonetici',
            'sebep': 'Teknik ekip yönlendirildi.',
            'created_at': '2026-07-09T11:00:00Z',
          },
        ],
        'created_at': '2026-07-09T10:00:00Z',
        'updated_at': '2026-07-09T11:00:00Z',
      });
      expect(c.id, 'c-1');
      expect(c.baslik, 'Asansor arizali');
      expect(c.durum, TalepDurum.isEmri);
      expect(c.acanAd, 'Acme Sakin');
      expect(c.kategoriId, 'k-1');
      expect(c.kategoriAd, 'Arıza');
      expect(c.isEmriId, 't-9');
      expect(c.isEmriDurum, 'acik');
      expect(c.fotograflar, hasLength(2));
      expect(c.fotograflar.first.fotoUrl, contains('X-Amz-Signature'));
      expect(c.gecmis, hasLength(2));
      expect(c.gecmis[1].durum, TalepDurum.isEmri);
      expect(c.gecmis[1].actorRole, 'yonetici');
      expect(c.gecmis[1].sebep, 'Teknik ekip yönlendirildi.');
    });

    test('kategorisiz/foto\'suz acik talep: opsiyonel alanlar bos/null', () {
      final c = Complaint.fromJson(const {
        'id': 'c-2',
        'acan_user_id': 'u-1',
        'baslik': 'Öneri',
        'mesaj': 'Bank konulsun.',
        'durum': 'acik',
        'created_at': '2026-07-09T10:00:00Z',
        'updated_at': '2026-07-09T10:00:00Z',
      });
      expect(c.durum, TalepDurum.acik);
      expect(c.kategoriId, isNull);
      expect(c.kategoriAd, isNull);
      expect(c.isEmriId, isNull);
      expect(c.isEmriDurum, isNull);
      expect(c.fotograflar, isEmpty);
      expect(c.gecmis, isEmpty);
    });

    test('eksik/bozuk alanlar cokme yaratmaz (savunmaci varsayilanlar)', () {
      final c = Complaint.fromJson(const {'id': 'c-3'});
      expect(c.baslik, '');
      expect(c.mesaj, '');
      expect(c.durum, TalepDurum.unknown);
      expect(c.fotograflar, isEmpty);
      expect(c.gecmis, isEmpty);
      // Gecersiz tarih epoch'a duser (parse hatasi yerine).
      expect(c.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('ComplaintPhoto.fromJson', () {
    test('alanlar eslenir; foto_url opsiyonel', () {
      final p = ComplaintPhoto.fromJson(const {
        'id': 'f-1',
        'foto_key': 't1/complaints/a.jpg',
        'sira': 2,
        'foto_url': 'http://x/a.jpg',
      });
      expect(p.id, 'f-1');
      expect(p.fotoKey, 't1/complaints/a.jpg');
      expect(p.sira, 2);
      expect(p.fotoUrl, 'http://x/a.jpg');

      final noUrl = ComplaintPhoto.fromJson(const {'id': 'f-2'});
      expect(noUrl.fotoUrl, isNull);
      expect(noUrl.sira, 0);
    });
  });

  group('ComplaintHistory.fromJson', () {
    test('durum/rol/sebep/zaman eslenir; user_id ASLA tasinmaz', () {
      final h = ComplaintHistory.fromJson(const {
        'durum': 'reddedildi',
        'actor_role': 'admin',
        'sebep': 'Yetki dışı talep.',
        'user_id': 'GIZLI',
        'created_at': '2026-07-09T12:00:00Z',
      });
      expect(h.durum, TalepDurum.reddedildi);
      expect(h.actorRole, 'admin');
      expect(h.sebep, 'Yetki dışı talep.');
      expect(h.createdAt.toUtc().hour, 12);
    });
  });

  group('ComplaintDraft.toJson', () {
    test('kategori_id null ise yazilmaz; foto_keys her zaman dizi', () {
      const d = ComplaintDraft(baslik: 'B', mesaj: 'M');
      expect(d.toJson(), {'baslik': 'B', 'mesaj': 'M', 'foto_keys': <String>[]});
    });

    test('kategori_id + foto_keys dolu ise tasinir', () {
      const d = ComplaintDraft(
        baslik: 'B',
        mesaj: 'M',
        kategoriId: 'k-1',
        fotoKeys: ['t/x.jpg', 't/y.jpg'],
      );
      expect(d.toJson(), {
        'baslik': 'B',
        'mesaj': 'M',
        'kategori_id': 'k-1',
        'foto_keys': ['t/x.jpg', 't/y.jpg'],
      });
    });
  });

  group('ComplaintConvertDraft.toJson', () {
    test('atanan + ASCII oncelik her zaman; kategori/not opsiyonel', () {
      const d = ComplaintConvertDraft(
        atananUserId: 'u-9',
        oncelik: TalepOncelik.yuksek,
      );
      expect(d.toJson(), {'atanan_user_id': 'u-9', 'oncelik': 'yuksek'});
    });

    test('kategori_id + not (literal alan adi "not") dolu ise yazilir', () {
      const d = ComplaintConvertDraft(
        atananUserId: 'u-9',
        oncelik: TalepOncelik.dusuk,
        kategoriId: 'k-2',
        not_: 'Acele değil.',
      );
      expect(d.toJson(), {
        'atanan_user_id': 'u-9',
        'oncelik': 'dusuk',
        'kategori_id': 'k-2',
        'not': 'Acele değil.',
      });
    });

    test('oncelik varsayilani orta', () {
      const d = ComplaintConvertDraft(atananUserId: 'u-9');
      expect(d.toJson()['oncelik'], 'orta');
    });
  });

  group('ComplaintResolveDraft.toJson', () {
    test('cozum_notu null ise yazilmaz (bos govde)', () {
      const d = ComplaintResolveDraft();
      expect(d.toJson(), isEmpty);
    });

    test('cozum_notu doluysa tasinir', () {
      const d = ComplaintResolveDraft(cozumNotu: 'Yerinde giderildi.');
      expect(d.toJson(), {'cozum_notu': 'Yerinde giderildi.'});
    });
  });

  group('ComplaintDeclineDraft.toJson', () {
    test('sebep ZORUNLU olarak yazilir', () {
      const d = ComplaintDeclineDraft(sebep: 'Mükerrer talep.');
      expect(d.toJson(), {'sebep': 'Mükerrer talep.'});
    });
  });
}
