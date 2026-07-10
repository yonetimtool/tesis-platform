import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';

void main() {
  group('RezervasyonDurum.fromWire', () {
    test('bilinen degerler eslesir', () {
      expect(RezervasyonDurum.fromWire('bekliyor'), RezervasyonDurum.bekliyor);
      expect(
          RezervasyonDurum.fromWire('onaylandi'), RezervasyonDurum.onaylandi);
      expect(RezervasyonDurum.fromWire('reddedildi'),
          RezervasyonDurum.reddedildi);
    });

    test('null/bilinmeyen deger unknown (ileri surum COKMEZ)', () {
      expect(RezervasyonDurum.fromWire(null), RezervasyonDurum.unknown);
      expect(RezervasyonDurum.fromWire('iptal'), RezervasyonDurum.unknown);
    });
  });

  group('OrtakAlan.fromJson', () {
    test('tam kayit parse edilir', () {
      final a = OrtakAlan.fromJson(const {
        'id': 'a-1',
        'ad': 'Havuz',
        'aciklama': 'Acik yuzme havuzu',
        'aktif': false,
        'created_at': '2026-07-10T09:00:00Z',
      });
      expect(a.id, 'a-1');
      expect(a.ad, 'Havuz');
      expect(a.aciklama, 'Acik yuzme havuzu');
      expect(a.aktif, isFalse);
    });

    test('eksik alanlarda COKMEZ; aktif varsayilan true', () {
      final a = OrtakAlan.fromJson(const {});
      expect(a.id, '');
      expect(a.aktif, isTrue);
    });
  });

  group('Rezervasyon.fromJson', () {
    test('tam kayit (onaylanmis) parse edilir', () {
      final r = Rezervasyon.fromJson(const {
        'id': 'r-1',
        'alan_id': 'a-1',
        'alan_ad': 'Havuz',
        'unit_id': 'u-1',
        'unit_no': 'A-12',
        'tarih': '2026-07-15',
        'baslangic': '10:00',
        'bitis': '12:00',
        'kisi_sayisi': 4,
        'notlar': 'Aile yuzme saati',
        'durum': 'onaylandi',
        'talep_eden_user_id': 'res-1',
        'talep_eden_ad': 'Acme Sakin',
        'onaylayan_user_id': 'yon-1',
        'onaylayan_ad': 'Acme Yonetici',
        'karar_zamani': '2026-07-11T08:00:00Z',
        'created_at': '2026-07-10T09:00:00Z',
      });
      expect(r.id, 'r-1');
      expect(r.alanAd, 'Havuz');
      expect(r.unitNo, 'A-12');
      expect(r.tarih, '2026-07-15');
      expect(r.baslangic, '10:00');
      expect(r.bitis, '12:00');
      expect(r.kisiSayisi, 4);
      expect(r.durum, RezervasyonDurum.onaylandi);
      expect(r.bekliyor, isFalse);
      expect(r.talepEdenAd, 'Acme Sakin');
      expect(r.onaylayanAd, 'Acme Yonetici');
      expect(r.kararZamani, DateTime.utc(2026, 7, 11, 8));
    });

    test('bekleyen kayit: karar alanlari null', () {
      final r = Rezervasyon.fromJson(const {
        'id': 'r-2',
        'alan_id': 'a-1',
        'unit_id': 'u-1',
        'tarih': '2026-07-15',
        'baslangic': '10:00',
        'bitis': '12:00',
        'kisi_sayisi': 2,
        'durum': 'bekliyor',
        'talep_eden_user_id': 'res-1',
        'created_at': '2026-07-10T09:00:00Z',
      });
      expect(r.bekliyor, isTrue);
      expect(r.onaylayanUserId, isNull);
      expect(r.onaylayanAd, isNull);
      expect(r.kararZamani, isNull);
      expect(r.notlar, isNull);
    });

    test('eksik/bozuk alanlarda COKMEZ (savunmaci parse)', () {
      final r = Rezervasyon.fromJson(const {});
      expect(r.id, '');
      expect(r.durum, RezervasyonDurum.unknown);
      expect(r.kisiSayisi, 0);
    });
  });

  group('RezervasyonDraft.toJson', () {
    test('notlar dolu ise yazilir', () {
      expect(
        const RezervasyonDraft(
          alanId: 'a-1',
          tarih: '2026-07-15',
          baslangic: '10:00',
          bitis: '12:00',
          kisiSayisi: 4,
          notlar: 'Aile',
        ).toJson(),
        {
          'alan_id': 'a-1',
          'tarih': '2026-07-15',
          'baslangic': '10:00',
          'bitis': '12:00',
          'kisi_sayisi': 4,
          'notlar': 'Aile',
        },
      );
    });

    test('notlar null/bos ise JSON\'a HIC yazilmaz', () {
      expect(
        const RezervasyonDraft(
          alanId: 'a-1',
          tarih: '2026-07-15',
          baslangic: '10:00',
          bitis: '12:00',
          kisiSayisi: 2,
        ).toJson(),
        {
          'alan_id': 'a-1',
          'tarih': '2026-07-15',
          'baslangic': '10:00',
          'bitis': '12:00',
          'kisi_sayisi': 2,
        },
      );
    });
  });

  group('OrtakAlanDraft.toJson', () {
    test('aciklama/aktif dolu ise yazilir; bos/null yazilmaz', () {
      expect(
        const OrtakAlanDraft(ad: 'Havuz', aciklama: 'Acik havuz', aktif: false)
            .toJson(),
        {'ad': 'Havuz', 'aciklama': 'Acik havuz', 'aktif': false},
      );
      expect(
        const OrtakAlanDraft(ad: 'Havuz').toJson(),
        {'ad': 'Havuz'},
      );
    });
  });
}
