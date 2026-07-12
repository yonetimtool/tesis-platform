import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';

void main() {
  group('Complaint.fromJson', () {
    test('tam govde eslenir (yanitli + gorselli)', () {
      final c = Complaint.fromJson(const {
        'id': 'c-1',
        'baslik': 'Asansor arizali',
        'mesaj': 'A blok asansoru durdu.',
        'durum': 'cozuldu',
        'acan_user_id': 'u-1',
        'acan_ad': 'Acme Sakin',
        'foto_key': 't1/tasks/abc.jpg',
        'foto_url': 'http://minio.local/x.jpg?X-Amz-Signature=s',
        'yonetici_yaniti': 'Servis cagrildi.',
        'yanitlayan_user_id': 'u-2',
        'yanit_zamani': '2026-07-09T11:00:00Z',
        'created_at': '2026-07-09T10:00:00Z',
        'updated_at': '2026-07-09T11:00:00Z',
      });
      expect(c.baslik, 'Asansor arizali');
      expect(c.durum, ComplaintDurum.cozuldu);
      expect(c.acanAd, 'Acme Sakin');
      expect(c.fotoUrl, contains('X-Amz-Signature'));
      expect(c.yanitli, isTrue);
      expect(c.yanitZamani, isNotNull);
    });

    test('yanitsiz/foto\'suz talep: opsiyonel alanlar null (geriye uyumlu)',
        () {
      final c = Complaint.fromJson(const {
        'id': 'c-2',
        'baslik': 'Oneri',
        'mesaj': 'Bank konulsun.',
        'durum': 'acik',
        'acan_user_id': 'u-1',
        'created_at': '2026-07-09T10:00:00Z',
        'updated_at': '2026-07-09T10:00:00Z',
      });
      expect(c.durum, ComplaintDurum.acik);
      expect(c.fotoKey, isNull);
      expect(c.fotoUrl, isNull);
      expect(c.yanitli, isFalse);
      expect(c.yanitZamani, isNull);
    });

    test('eksik/bozuk alanlar cokme yaratmaz (savunmaci varsayilanlar)', () {
      final c = Complaint.fromJson(const {'id': 'c-3'});
      expect(c.baslik, '');
      expect(c.durum, ComplaintDurum.unknown);
      expect(c.yanitli, isFalse);
    });
  });

  test('ComplaintDurum.fromWire bilinmeyeni unknown yapar', () {
    expect(ComplaintDurum.fromWire('acik'), ComplaintDurum.acik);
    expect(ComplaintDurum.fromWire('inceleniyor'), ComplaintDurum.inceleniyor);
    expect(ComplaintDurum.fromWire('cozuldu'), ComplaintDurum.cozuldu);
    expect(ComplaintDurum.fromWire('kapandi'), ComplaintDurum.unknown);
    expect(ComplaintDurum.fromWire(null), ComplaintDurum.unknown);
  });

  group('ComplaintDraft.toJson', () {
    test('fotoKey null ise foto_key HIC yazilmaz', () {
      const d = ComplaintDraft(baslik: 'B', mesaj: 'M');
      expect(d.toJson(), {'baslik': 'B', 'mesaj': 'M'});
    });

    test('fotoKey doluysa foto_key tasinir', () {
      const d = ComplaintDraft(baslik: 'B', mesaj: 'M', fotoKey: 't/x.jpg');
      expect(d.toJson(), {'baslik': 'B', 'mesaj': 'M', 'foto_key': 't/x.jpg'});
    });
  });

  group('kategori (Wave 1 #3)', () {
    test('ComplaintKategori.fromWire: bilinen degerler + null/bilinmeyen', () {
      expect(ComplaintKategori.fromWire('gurultu'), ComplaintKategori.gurultu);
      expect(ComplaintKategori.fromWire('goruntu'), ComplaintKategori.goruntu);
      expect(ComplaintKategori.fromWire('diger'), ComplaintKategori.diger);
      expect(ComplaintKategori.fromWire(null), isNull); // belirtilmemis
      expect(ComplaintKategori.fromWire('acayip'), isNull);
    });

    test('TR etiketler: gurultu/goruntu kirliligi', () {
      expect(ComplaintKategori.gurultu.label, 'Gürültü kirliliği');
      expect(ComplaintKategori.goruntu.label, 'Görüntü kirliliği');
      expect(ComplaintKategori.diger.label, 'Diğer');
    });

    test('Complaint.fromJson kategoriyi okur; eski kayitta null', () {
      final yeni = Complaint.fromJson(const {
        'id': 'c-9',
        'baslik': 'Gece muzik',
        'mesaj': 'Cok ses var.',
        'durum': 'acik',
        'acan_user_id': 'u-1',
        'kategori': 'gurultu',
        'created_at': '2026-07-10T10:00:00Z',
        'updated_at': '2026-07-10T10:00:00Z',
      });
      expect(yeni.kategori, ComplaintKategori.gurultu);

      final eski = Complaint.fromJson(const {'id': 'c-10', 'durum': 'acik'});
      expect(eski.kategori, isNull);
    });

    test('ComplaintDraft.toJson: kategori doluysa yazilir, null ise yazilmaz',
        () {
      const kategorili = ComplaintDraft(
        baslik: 'B',
        mesaj: 'M',
        kategori: ComplaintKategori.goruntu,
      );
      expect(kategorili.toJson(),
          {'baslik': 'B', 'mesaj': 'M', 'kategori': 'goruntu'});

      const kategorisiz = ComplaintDraft(baslik: 'B', mesaj: 'M');
      expect(kategorisiz.toJson(), {'baslik': 'B', 'mesaj': 'M'});
    });
  });

  group('ComplaintReplyDraft.toJson', () {
    test('yalniz dolu alanlar yazilir (PATCH exclude_unset uyumu)', () {
      const d = ComplaintReplyDraft(durum: ComplaintDurum.inceleniyor);
      expect(d.toJson(), {'durum': 'inceleniyor'});
      expect(d.bos, isFalse);

      const y = ComplaintReplyDraft(yoneticiYaniti: 'Tamam.');
      expect(y.toJson(), {'yonetici_yaniti': 'Tamam.'});
    });

    test('bos taslak isaretlenir (sunucu bos govdeye 422)', () {
      const d = ComplaintReplyDraft();
      expect(d.bos, isTrue);
      expect(d.toJson(), isEmpty);
    });
  });
}
