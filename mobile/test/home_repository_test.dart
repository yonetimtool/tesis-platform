/// [MockHomeRepository] SAYI TASIMAZ: yalnizca referans gorsellerin DUZENINI
/// (ikon/baslik/renk/sira/rota) tasir.
///
/// G1-G7 kapandiktan sonra sozlesme boslugu KALMADI: hicbir kart/kutu
/// 'Yakında' gostermez. Bu test iki seyi KILITLER:
///   1. duzen (baslik sirasi + rotalar) referanstan sapmasin,
///   2. gercek uca bagli hicbir kart SABIT bir sayi tasimasin (altMetin
///      null = yukleniyor) — yani ekranda uydurma deger BELIREMESIN.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';

const _mock = MockHomeRepository();

/// Sayac DEGIL, sabit bolum etiketi olan kartlar (uc gerektirmez).
const _etiketKartlari = {'Aylık Özet', 'Devriye', 'Kurallar', 'İletişim'};

void main() {
  group('homeVaryantForRole — rol → referans duzen', () {
    test('sakin → sakin; yonetici + admin → yonetici; security → gorevli; '
        'tesis gorevlisi → KENDI varyanti (kart seti farkli)', () {
      expect(homeVaryantForRole(UserRole.resident), HomeVaryant.sakin);
      expect(homeVaryantForRole(UserRole.yonetici), HomeVaryant.yonetici);
      expect(homeVaryantForRole(UserRole.admin), HomeVaryant.yonetici);
      expect(homeVaryantForRole(UserRole.security), HomeVaryant.gorevli);
      expect(
        homeVaryantForRole(UserRole.tesisGorevlisi),
        HomeVaryant.tesisGorevlisi,
      );
    });

    test('eslesmeyen/eksik rol icin GUVENLI varsayilan gorevli', () {
      expect(homeVaryantForRole(UserRole.unknown), HomeVaryant.gorevli);
    });
  });

  group('UYDURMA SAYI YOK — taban yalniz bosluklari doldurur', () {
    for (final varyant in HomeVaryant.values) {
      test('$varyant: sayac ya null (yukleniyor) ya sabit bolum etiketi; '
          "'Yakında' KALMADI", () {
        for (final k in _mock.hizliErisim(varyant)) {
          final m = k.altMetin;
          expect(
            m == null || _etiketKartlari.contains(m),
            isTrue,
            reason: '${k.baslik} kartinda sabit deger var: "$m"',
          );
        }
      });
    }

    test('yonetici Hızlı Özet: DORT kutunun tamami gercek uca bagli — hepsi '
        'DEGERSIZ baslar (otopark artik /parking/occupancy)', () {
      final kutular = _mock.ozet();
      expect([for (final k in kutular) k.etiket], [
        'Toplam Daire',
        'Toplam Tahsilat',
        'Aidat Tahsilat Oranı',
        'Otopark Doluluk',
      ]);
      expect([for (final k in kutular) k.deger], [null, null, null, null]);
      expect(kutular.last.altEtiket, 'Şu An');
    });
  });

  group('gorevli (security) — 4\'LU IZGARA: 8 kart, sirali', () {
    test('baslik sirasi: referans 5 kart + gunluk is kartlari', () {
      expect(
        [for (final k in _mock.hizliErisim(HomeVaryant.gorevli)) k.baslik],
        [
          'Vardiya Durum',
          'Kargo',
          'Ziyaretçi',
          'Araç Plaka',
          'İhlaller',
          'Görevlerim',
          'Demirbaş',
          'Turlarım',
        ],
      );
    });

    test('8 kart = 4 sutunda TAM iki satir (dengeli izgara)', () {
      expect(_mock.hizliErisim(HomeVaryant.gorevli).length % 4, 0);
    });

    test('sayaci VAR ama liste ekrani olmayan kartlar rotasiz kalir '
        '(dokununca "yakında"); sayac yine de GERCEK uctan gelir', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli))
          if (k.rota == null) k
      ];
      expect([for (final k in rotasiz) k.baslik], ['Araç Plaka', 'İhlaller']);
      // Sabit metin YOK: sayac gercek uctan gelene kadar iskelet.
      expect([for (final k in rotasiz) k.altMetin], [null, null]);
    });
  });

  group('tesis gorevlisi — 4\'LU IZGARA: kendi is kartlari (KVKK)', () {
    final kartlar = _mock.hizliErisim(HomeVaryant.tesisGorevlisi);

    test('baslik sirasi', () {
      expect([for (final k in kartlar) k.baslik], [
        'Vardiya Durum',
        'Görevlerim',
        'Demirbaş',
        'Talep / Arıza',
        'Duyurular',
        'Etkinlikler',
        'Site Kuralları',
        'Yönetici',
      ]);
    });

    test('KVKK: ziyaretci/kargo/plaka/ihlal kartlari HIC YOK — bu rolun '
        'ucleri 403 doner, kart kalici "—" gosterirdi', () {
      final basliklar = {for (final k in kartlar) k.baslik};
      for (final yasak in ['Kargo', 'Ziyaretçi', 'Araç Plaka', 'İhlaller']) {
        expect(basliklar.contains(yasak), isFalse, reason: yasak);
      }
    });

    test('her kartin bir rotasi VAR (rotasiz/olu kart yok)', () {
      expect([for (final k in kartlar) if (k.rota == null) k.baslik], isEmpty);
    });

    test('8 kart = 4 sutunda TAM iki satir', () {
      expect(kartlar.length % 4, 0);
    });
  });

  group('site-sakini.jpeg — 4x2 izgara', () {
    test('8 kart, sira gorselle birebir', () {
      final kartlar = _mock.hizliErisim(HomeVaryant.sakin);
      expect(
        [for (final k in kartlar) k.baslik],
        [
          'Ziyaretçiler',
          'Kargolarım',
          'Aidat Bilgileri',
          'Gürültü Şikayeti',
          'Geri Bildirim',
          'Şikayetlerim',
          'Duyurular',
          'Site Raporları',
        ],
      );
    });

    test('sakin izgarasinin TAMAMININ ucu var (rotasiz kart yok)', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.sakin))
          if (k.rota == null) k.baslik
      ];
      expect(rotasiz, isEmpty);
    });

    test('aidat kartinin iki satiri da gercek veriyi bekler', () {
      final aidat = _mock
          .hizliErisim(HomeVaryant.sakin)
          .firstWhere((k) => k.baslik == 'Aidat Bilgileri');
      expect(aidat.altMetin, isNull);
      expect(aidat.ikinciAltMetin, isNull);
    });
  });

  group('yonetici.jpeg — 4x2 izgara', () {
    test('8 kart, sira gorselle birebir', () {
      expect(
        [for (final k in _mock.hizliErisim(HomeVaryant.yonetici)) k.baslik],
        [
          'Vardiya Durumu',
          'Görevler',
          'Aidat Durumu',
          'Otopark Kullanımı',
          'İhlaller',
          'Geri Bildirim',
          'Şikayetler',
          'Raporlar',
        ],
      );
    });

    test('liste ekrani olmayan kartlar rotasiz: Otopark Kullanımı + İhlaller '
        '(sayaclari GERCEK uctan)', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.yonetici))
          if (k.rota == null) k
      ];
      expect([for (final k in rotasiz) k.baslik],
          ['Otopark Kullanımı', 'İhlaller']);
      expect([for (final k in rotasiz) k.altMetin], [null, null]);
    });
  });
}
