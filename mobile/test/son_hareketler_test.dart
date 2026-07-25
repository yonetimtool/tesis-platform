import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/domain/son_hareketler.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/reports/domain/report_models.dart'
    show SonTamamlama;
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';

void main() {
  group('hareketZamanEtiketi — deterministik (now disaridan)', () {
    final now = DateTime(2026, 7, 23, 14, 0);

    test('ayni gun: HH:mm', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 23, 9, 5), now), '09:05');
    });
    test('dun: "Dün"', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 22, 23, 0), now), 'Dün');
    });
    test('daha eski: dd.MM', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 1, 8, 0), now), '01.07');
    });
  });

  group('residentHareketleri — kargo+ziyaretci+aidat birlesik akisi', () {
    Kargo kargo(String id, DateTime t,
            {KargoDurum durum = KargoDurum.bekliyor, DateTime? teslim}) =>
        Kargo(
          id: id,
          unitId: 'u1',
          unitNo: '12',
          firma: 'Mng',
          durum: durum,
          kaydedenUserId: 'g1',
          createdAt: t,
          teslimZamani: teslim,
        );

    Visitor ziyaretci(String id, DateTime t) => Visitor(
          id: id,
          unitId: 'u1',
          unitNo: '12',
          ziyaretciAd: 'Ahmet Yılmaz',
          kaydedenUserId: 'g1',
          targetResidentUserId: 'r1',
          createdAt: t,
        );

    MyDuesUnit daire(List<DuesPayment> payments) => MyDuesUnit(
          unitId: 'u1',
          no: '12',
          tahakkukKurus: 0,
          odenenKurus: 0,
          bakiyeKurus: 0,
          payments: payments,
        );

    test('kaynaklar eslesir, zamana gore DESC siralanir, en fazla 5', () {
      final h = residentHareketleri(
        kargolar: [
          kargo('k1', DateTime(2026, 7, 23, 9)), // bekliyor -> kaydedildi
          kargo('k2', DateTime(2026, 7, 20),
              durum: KargoDurum.teslimAlindi,
              teslim: DateTime(2026, 7, 23, 11)), // teslim zamani esas
        ],
        ziyaretciler: [ziyaretci('z1', DateTime(2026, 7, 23, 10))],
        duesUnits: [
          daire([
            DuesPayment(
                tutarKurus: 125000,
                odemeZamani: DateTime(2026, 7, 23, 8),
                yontem: 'havale',
                durum: 'basarili'),
            DuesPayment(
                tutarKurus: 99900,
                odemeZamani: DateTime(2026, 7, 23, 12),
                yontem: 'havale',
                durum: 'iptal'), // basarisiz -> AKISA GIRMEZ
          ]),
        ],
      );

      expect(h.map((e) => e.baslik).toList(), [
        'Kargo Teslim Edildi', // 11:00
        'Ziyaretçi Girişi', // 10:00
        'Kargo Kaydedildi', // 09:00
        'Aidat Ödemesi', // 08:00
      ]);
      expect(h[1].altBaslik, contains('Ahmet Yılmaz'));
      expect(h[3].altBaslik, contains('₺1.250,00'));
    });

    test('5\'ten fazla hareket: yalniz en yeni 5', () {
      final h = residentHareketleri(
        kargolar: [
          for (var i = 1; i <= 7; i++) kargo('k$i', DateTime(2026, 7, i)),
        ],
        ziyaretciler: const [],
        duesUnits: const [],
      );
      expect(h, hasLength(5));
      expect(h.first.zaman, DateTime(2026, 7, 7));
    });

    test('tum kaynaklar bos: bos liste', () {
      expect(
        residentHareketleri(
            kargolar: const [], ziyaretciler: const [], duesUnits: const []),
        isEmpty,
      );
    });
  });

  group('yonetimHareketleri — bildirimlerden yonetim akisi', () {
    AppNotification bildirim(String tip, DateTime? t, {String mesaj = 'm'}) =>
        AppNotification(
            id: tip, tip: tip, mesaj: mesaj, okundu: false, createdAt: t);

    test('tip -> baslik/tur eslesir; DESC siralanir; en fazla 5', () {
      final h = yonetimHareketleri(bildirimler: [
        bildirim('kacirilan_tur', DateTime(2026, 7, 23, 9),
            mesaj: 'Gece turu kaçırıldı'),
        bildirim('gecikmis_okutma', DateTime(2026, 7, 23, 11)),
        bildirim('eksik_checkpoint', DateTime(2026, 7, 23, 10)),
        bildirim('baska_tip', DateTime(2026, 7, 23, 8)),
      ]);

      expect(h.map((e) => e.baslik).toList(), [
        'Gecikmiş Okutma', // 11
        'Eksik Nokta', // 10
        'Kaçırılan Tur', // 09
        'Bildirim', // bilinmeyen tip -> genel etiket
      ]);
      expect(h.first.tip, HareketTip.uyari); // gecikme amber
      expect(h[2].tip, HareketTip.alarm); // kacirilan_tur kirmizi
      expect(h[2].altBaslik, 'Gece turu kaçırıldı');
    });

    test('createdAt NULL bildirim akisa GIRMEZ (siralanamaz)', () {
      final h = yonetimHareketleri(bildirimler: [
        bildirim('kacirilan_tur', null),
        bildirim('eksik_checkpoint', DateTime(2026, 7, 23)),
      ]);
      expect(h, hasLength(1));
      expect(h.single.baslik, 'Eksik Nokta');
    });

    test('5\'ten fazla: yalniz en yeni 5', () {
      final h = yonetimHareketleri(bildirimler: [
        for (var i = 1; i <= 7; i++)
          bildirim('t$i', DateTime(2026, 7, i)),
      ]);
      expect(h, hasLength(5));
      expect(h.first.zaman, DateTime(2026, 7, 7));
    });

    test('DORT kaynak (bildirim + talep + odeme + gorev) TEK akista '
        'zamana gore harmanlanir', () {
      final h = yonetimHareketleri(
        bildirimler: [bildirim('kacirilan_tur', DateTime(2026, 7, 23, 8))],
        talepler: [
          _talep('t1', TalepDurum.acik, DateTime(2026, 7, 23, 11),
              baslik: 'Asansör arızası', kategori: 'Tesisat'),
        ],
        odemeler: [
          DuesPayment(
            tutarKurus: 125000,
            odemeZamani: DateTime(2026, 7, 23, 10),
            yontem: 'elden',
            durum: 'basarili',
            donem: '2026-07',
          ),
          // basarisiz odeme akisa GIRMEZ
          DuesPayment(
            tutarKurus: 999,
            odemeZamani: DateTime(2026, 7, 23, 23),
            yontem: 'elden',
            durum: 'iptal',
          ),
        ],
        tamamlamalar: [
          SonTamamlama(
            id: 'c1',
            kategoriAd: 'Temizlik',
            taskAdi: 'Çöp toplama',
            tamamlanmaZamani: DateTime(2026, 7, 23, 9),
          ),
        ],
      );

      expect(
        [for (final e in h) '${e.baslik}|${e.zaman.hour}'],
        [
          'Yeni Talep|11',
          'Aidat Ödemesi|10',
          'Görev Tamamlandı|9',
          'Kaçırılan Tur|8',
        ],
      );
      expect(h[0].altBaslik, 'Asansör arızası - Tesisat');
      expect(h[0].tip, HareketTip.talep);
      expect(h[2].altBaslik, 'Çöp toplama - Temizlik');
      expect(h[2].tip, HareketTip.gorevTamamlama);
    });

    test('talep basligi DURUMDAN turer', () {
      final h = yonetimHareketleri(talepler: [
        _talep('a', TalepDurum.isEmri, DateTime(2026, 7, 23, 3)),
        _talep('b', TalepDurum.cozuldu, DateTime(2026, 7, 23, 2)),
        _talep('c', TalepDurum.reddedildi, DateTime(2026, 7, 23, 1)),
      ]);
      expect([for (final e in h) e.baslik],
          ['İş Emri Açıldı', 'Talep Çözüldü', 'Talep Reddedildi']);
    });
  });

  group('sahaHareketleri — gorevli akisi', () {
    test('security: ziyaretci + kargo + gorev + bildirim harmanlanir', () {
      final h = sahaHareketleri(
        ziyaretciler: [
          Visitor(
            id: 'z1',
            unitId: 'u1',
            unitNo: '12',
            ziyaretciAd: 'Ahmet Yılmaz',
            kaydedenUserId: 'g1',
            targetResidentUserId: 'r1',
            createdAt: DateTime(2026, 7, 23, 12),
          ),
        ],
        kargolar: [
          Kargo(
            id: 'k1',
            unitId: 'u1',
            unitNo: '12',
            firma: 'Aras',
            durum: KargoDurum.bekliyor,
            kaydedenUserId: 'g1',
            createdAt: DateTime(2026, 7, 23, 11),
          ),
        ],
        tamamlamalar: [
          SonTamamlama(
            id: 'c1',
            kategoriAd: 'Devriye',
            tamamlanmaZamani: DateTime(2026, 7, 23, 10),
          ),
        ],
        bildirimler: [
          AppNotification(
            id: 'n1',
            tip: 'kacirilan_tur',
            mesaj: 'Tur kaçırıldı',
            createdAt: DateTime(2026, 7, 23, 9),
          ),
        ],
      );

      expect([for (final e in h) e.baslik], [
        'Ziyaretçi Girişi',
        'Kargo Kaydedildi',
        'Görev Tamamlandı',
        'Kaçırılan Tur',
      ]);
      // taskAdi yoksa alt baslik kategoridir
      expect(h[2].altBaslik, 'Devriye');
    });

    test('tesis_gorevlisi (KVKK): yalniz gorev tamamlamalari verilir', () {
      final h = sahaHareketleri(tamamlamalar: [
        SonTamamlama(
          id: 'c1',
          kategoriAd: 'Temizlik',
          taskAdi: 'Merdiven',
          tamamlanmaZamani: DateTime(2026, 7, 23, 10),
        ),
      ]);
      expect(h, hasLength(1));
      expect(h.single.baslik, 'Görev Tamamlandı');
    });

    test('tum kaynaklar bos: bos liste', () {
      expect(sahaHareketleri(), isEmpty);
    });
  });
}

Complaint _talep(
  String id,
  TalepDurum durum,
  DateTime t, {
  String baslik = 'Talep',
  String? kategori,
}) =>
    Complaint(
      id: id,
      acanUserId: 'r1',
      baslik: baslik,
      mesaj: 'm',
      kategoriAd: kategori,
      durum: durum,
      fotograflar: const [],
      gecmis: const [],
      createdAt: t,
      updatedAt: t,
    );
