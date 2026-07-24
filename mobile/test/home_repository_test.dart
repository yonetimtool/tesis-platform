/// MockHomeRepository referans gorsellerin (docs/design-refs) DEGERLERINI
/// tasir. Bu test o degerleri KILITLER: bir kart metni/sayaci degisirse ana
/// ekran referanstan sapmis demektir ve burada yakalanir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';

const _mock = MockHomeRepository();

void main() {
  group('homeVaryantForRole — rol → referans duzen', () {
    test('sakin → sakin; yonetici + admin → yonetici; saha → gorevli', () {
      expect(homeVaryantForRole(UserRole.resident), HomeVaryant.sakin);
      expect(homeVaryantForRole(UserRole.yonetici), HomeVaryant.yonetici);
      expect(homeVaryantForRole(UserRole.admin), HomeVaryant.yonetici);
      expect(homeVaryantForRole(UserRole.security), HomeVaryant.gorevli);
      expect(homeVaryantForRole(UserRole.tesisGorevlisi), HomeVaryant.gorevli);
    });

    test('eslesmeyen/eksik rol icin GUVENLI varsayilan gorevli', () {
      expect(homeVaryantForRole(UserRole.unknown), HomeVaryant.gorevli);
    });
  });

  group('gorevli.jpeg — hizli erisim seridi (5 kart, sirali)', () {
    test('baslik + sayac ciftleri gorselle birebir', () {
      final kartlar = _mock.hizliErisim(HomeVaryant.gorevli);
      expect(
        [for (final k in kartlar) '${k.baslik}|${k.altMetin}'],
        [
          'Vardiya Durum|3 Aktif',
          'Kargo|5 Bekliyor',
          'Ziyaretçi|2 İçeride',
          'Araç Plaka|8 Giriş',
          'İhlaller|4 Yeni',
        ],
      );
    });

    test('karsiligi olmayan kartlarin rotasi YOK (uc uydurulmadi)', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli))
          if (k.rota == null) k.baslik
      ];
      expect(rotasiz, ['Araç Plaka', 'İhlaller']);
    });

    test('son hareketler 5 satir, metinler gorselle birebir', () {
      final satirlar = _mock.hareketler(HomeVaryant.gorevli);
      expect(satirlar.length, 5);
      expect(
        [for (final s in satirlar) '${s.baslik}|${s.altBaslik}|${s.zaman}'],
        [
          'Kamera İhlal Tespiti|Otopark Girişi - Kamera 3|09:32',
          'Kapı Açıldı|A Blok - Ana Giriş|09:21',
          'Araç Girişi|34 ABC 123 - BMW Siyah|09:15',
          'Kargo Teslim Alındı|Mng Kargo - 245781236|09:05',
          'Ziyaretçi Girişi|Ahmet Yılmaz - Daire 15|08:58',
        ],
      );
    });

    test('canli kamera seridi 4 kart', () {
      expect([for (final k in _mock.kameralar()) k.ad],
          ['Ana Giriş', 'Otopark', 'Arka Bahçe', 'B Blok Girişi']);
    });
  });

  group('site-sakini.jpeg — 4x2 izgara + odeme + duyuru', () {
    test('8 kart, sira ve sayaclar gorselle birebir', () {
      final kartlar = _mock.hizliErisim(HomeVaryant.sakin);
      expect(kartlar.length, 8);
      expect(
        [for (final k in kartlar) '${k.baslik}|${k.altMetin}'],
        [
          'Ziyaretçiler|2 Bekliyor',
          'Kargolarım|1 Bekliyor',
          'Aidat Bilgileri|₺1.250,00',
          'Gürültü Şikayeti|Bildirim Yap',
          'Geri Bildirim|2 Yeni',
          'Şikayetlerim|1 Açık',
          'Duyurular|3 Yeni',
          'Site Raporları|Aylık Özet',
        ],
      );
    });

    test('aidat karti ikinci satiri yesil "Borç Yok"', () {
      final aidat = _mock
          .hizliErisim(HomeVaryant.sakin)
          .firstWhere((k) => k.baslik == 'Aidat Bilgileri');
      expect(aidat.ikinciAltMetin, 'Borç Yok');
    });

    test('odeme ozeti gorseldeki degerler', () {
      final o = _mock.odeme();
      expect(o.buAyTutar, '₺1.250,00');
      expect(o.odendi, isTrue);
      expect(o.sonOdeme, '05.05.2026');
      expect(o.gelecekTarih, '05.06.2026');
      expect(o.gelecekTutar, '₺1.250,00');
    });

    test('duyuru karti gorseldeki metinler', () {
      final d = _mock.duyuru();
      expect(d.baslik, 'Bahçe Düzenlemesi');
      expect(d.govde, 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.');
      expect(d.tarih, '20 Mayıs – 09:00');
      expect(d.yeni, isTrue);
    });

    test('son hareketler 5 satir', () {
      final satirlar = _mock.hareketler(HomeVaryant.sakin);
      expect(satirlar.length, 5);
      expect(satirlar.first.baslik, 'Ziyaretçi Girişi');
      expect(satirlar.last.baslik, 'Aidat Ödemesi');
      expect(satirlar.last.zaman, '05.05.2026');
    });
  });

  group('yonetici.jpeg — 4x2 izgara + hizli ozet', () {
    test('8 kart, sira ve sayaclar gorselle birebir', () {
      expect(
        [
          for (final k in _mock.hizliErisim(HomeVaryant.yonetici))
            '${k.baslik}|${k.altMetin}'
        ],
        [
          'Vardiya Durumu|4 Aktif',
          'Görevler|6 Bekliyor',
          'Aidat Durumu|104 Daire',
          'Otopark Kullanımı|78 / 120',
          'İhlaller|5 Yeni',
          'Geri Bildirim|8 Yeni',
          'Şikayetler|3 Yeni',
          'Raporlar|Aylık Özet',
        ],
      );
    });

    test('hizli ozet 4 kutu (deger/etiket/alt-etiket)', () {
      expect(
        [
          for (final k in _mock.ozet())
            '${k.deger}|${k.etiket}|${k.altEtiket}'
        ],
        [
          '512|Toplam Daire|Tüm Site',
          '₺248.750|Toplam Tahsilat|Bu Ay',
          '%86|Aidat Tahsilat Oranı|Bu Ay',
          '78 / 120|Otopark Doluluk|%65',
        ],
      );
    });

    test('son hareketler 4 satir; aidat satiri turuncu ikon + mavi nokta', () {
      final satirlar = _mock.hareketler(HomeVaryant.yonetici);
      expect(satirlar.length, 4);
      final aidat = satirlar.firstWhere((s) => s.baslik == 'Aidat Ödemesi');
      expect(aidat.ikonAccent, isNot(aidat.noktaRengi));
    });
  });

  group('vardiya serisi — 3 vardiya + yonetici karti', () {
    test('gorseldeki dizilim', () {
      final kartlar = _mock.vardiyalar();
      expect([for (final k in kartlar) k.baslik],
          ['Sabah Vardiyası', 'Öğle Vardiyası', 'Gece Vardiyası', 'Yönetici']);
      expect(kartlar[2].durum, VardiyaDurum.planlandi);
      expect(kartlar[3].durum, VardiyaDurum.yonetici);
      expect(kartlar[3].altBaslik, 'Kerem Aşçı');
    });
  });
}
