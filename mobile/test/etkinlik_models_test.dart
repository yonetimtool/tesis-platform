import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';

void main() {
  group('KatilimDurum.fromWire', () {
    test('bilinen degerler eslesir', () {
      expect(KatilimDurum.fromWire('katiliyorum'), KatilimDurum.katiliyorum);
      expect(KatilimDurum.fromWire('katilmiyorum'), KatilimDurum.katilmiyorum);
    });

    test('null/bilinmeyen deger null (beyan verilmemis sayilir; cokme yok)',
        () {
      expect(KatilimDurum.fromWire(null), isNull);
      expect(KatilimDurum.fromWire('belki'), isNull);
    });
  });

  group('Etkinlik.fromJson', () {
    test('tam kayit (seffaf sayilar + kendi beyanim) parse edilir', () {
      final e = Etkinlik.fromJson(const {
        'id': 'e-1',
        'baslik': 'Mac izleme aksami',
        'aciklama': 'Buyuk ekranda milli mac.',
        'tarih': '2026-07-20T18:00:00Z',
        'konum': 'Sosyal tesis salonu',
        'olusturan_user_id': 'yon-1',
        'olusturan_ad': 'Acme Yonetici',
        'katiliyorum_sayisi': 12,
        'katilmiyorum_sayisi': 3,
        'benim_durumum': 'katiliyorum',
        'created_at': '2026-07-10T09:00:00Z',
        'updated_at': '2026-07-10T09:00:00Z',
      });
      expect(e.id, 'e-1');
      expect(e.baslik, 'Mac izleme aksami');
      expect(e.tarih, DateTime.utc(2026, 7, 20, 18));
      expect(e.konum, 'Sosyal tesis salonu');
      expect(e.olusturanAd, 'Acme Yonetici');
      expect(e.katiliyorumSayisi, 12);
      expect(e.katilmiyorumSayisi, 3);
      expect(e.benimDurumum, KatilimDurum.katiliyorum);
    });

    test('beyan verilmemis kayit: benimDurumum null, sayilar 0 varsayilan',
        () {
      final e = Etkinlik.fromJson(const {
        'id': 'e-2',
        'baslik': 'Genel kurul',
        'aciklama': 'x',
        'tarih': '2026-06-15T17:00:00Z',
        'olusturan_user_id': 'yon-1',
        'created_at': '2026-06-01T09:00:00Z',
        'updated_at': '2026-06-01T09:00:00Z',
      });
      expect(e.benimDurumum, isNull);
      expect(e.katiliyorumSayisi, 0);
      expect(e.katilmiyorumSayisi, 0);
      expect(e.konum, isNull);
    });

    test('gecmis/yaklasan ayrimi tarih uzerinden', () {
      final gecmis = Etkinlik.fromJson(const {
        'id': 'e-3',
        'baslik': 'x',
        'aciklama': 'y',
        'tarih': '2020-01-01T10:00:00Z',
        'olusturan_user_id': 'u',
        'created_at': '2020-01-01T00:00:00Z',
        'updated_at': '2020-01-01T00:00:00Z',
      });
      expect(gecmis.gecmis, isTrue);
      final yaklasan = Etkinlik.fromJson({
        'id': 'e-4',
        'baslik': 'x',
        'aciklama': 'y',
        'tarih': DateTime.now()
            .add(const Duration(days: 7))
            .toUtc()
            .toIso8601String(),
        'olusturan_user_id': 'u',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(yaklasan.gecmis, isFalse);
    });

    test('eksik/bozuk alanlarda COKMEZ (savunmaci parse)', () {
      final e = Etkinlik.fromJson(const {});
      expect(e.id, '');
      expect(e.katiliyorumSayisi, 0);
      expect(e.benimDurumum, isNull);
    });
  });

  group('EtkinlikDraft.toJson', () {
    test('konum dolu ise yazilir; tarih ISO8601 UTC', () {
      final json = EtkinlikDraft(
        baslik: 'Mac izleme',
        aciklama: 'Detay',
        tarih: DateTime.utc(2026, 7, 20, 18),
        konum: 'Salon',
      ).toJson();
      expect(json['baslik'], 'Mac izleme');
      expect(json['tarih'], '2026-07-20T18:00:00.000Z');
      expect(json['konum'], 'Salon');
    });

    test('konum null/bos ise JSON\'a HIC yazilmaz', () {
      final json = EtkinlikDraft(
        baslik: 'x',
        aciklama: 'y',
        tarih: DateTime.utc(2026, 7, 20, 18),
      ).toJson();
      expect(json.containsKey('konum'), isFalse);
      final json2 = EtkinlikDraft(
        baslik: 'x',
        aciklama: 'y',
        tarih: DateTime.utc(2026, 7, 20, 18),
        konum: '',
      ).toJson();
      expect(json2.containsKey('konum'), isFalse);
    });
  });
}
