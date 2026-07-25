/// [MockHomeRepository] artik SAYI TASIMAZ: referans gorsellerin DUZENINI
/// (ikon/baslik/renk/sira/rota) ve YALNIZCA sozlesmede karsiligi olmayan
/// kartlarin 'Yakında' etiketini tasir.
///
/// Bu test iki seyi KILITLER:
///   1. duzen (baslik sirasi + rotalar) referanstan sapmasin,
///   2. gercek uca bagli hicbir kart SABIT bir sayi tasimasin (altMetin
///      null = yukleniyor) — yani ekranda uydurma deger BELIREMESIN.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';

const _mock = MockHomeRepository();

/// Sozlesmede karsiligi OLMAYAN kartlarin tek isaretcisi.
const _yakinda = 'Yakında';

/// Sayac DEGIL, sabit aciklama etiketi olan kartlar (uc gerektirmez).
const _etiketKartlari = {'Bildirim Yap', 'Aylık Özet'};

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

  group('UYDURMA SAYI YOK — taban yalniz bosluklari doldurur', () {
    for (final varyant in HomeVaryant.values) {
      test('$varyant: sayac ya null (yukleniyor) ya "Yakında" ya sabit etiket',
          () {
        for (final k in _mock.hizliErisim(varyant)) {
          final m = k.altMetin;
          expect(
            m == null || m == _yakinda || _etiketKartlari.contains(m),
            isTrue,
            reason: '${k.baslik} kartinda sabit deger var: "$m"',
          );
        }
      });
    }

    test('yonetici Hızlı Özet: gercek uca bagli kutular DEGERSIZ baslar; '
        'yalniz otopark (MISSING-BACKEND) "—" + "Yakında"', () {
      final kutular = _mock.ozet();
      expect([for (final k in kutular) k.etiket], [
        'Toplam Daire',
        'Toplam Tahsilat',
        'Aidat Tahsilat Oranı',
        'Otopark Doluluk',
      ]);
      expect([for (final k in kutular.take(3)) k.deger], [null, null, null]);
      expect(kutular.last.deger, '—');
      expect(kutular.last.altEtiket, _yakinda);
    });
  });

  group('gorevli.jpeg — hizli erisim seridi (5 kart, sirali)', () {
    test('baslik sirasi gorselle birebir', () {
      expect(
        [for (final k in _mock.hizliErisim(HomeVaryant.gorevli)) k.baslik],
        ['Vardiya Durum', 'Kargo', 'Ziyaretçi', 'Araç Plaka', 'İhlaller'],
      );
    });

    test('karsiligi olmayan kartlarin rotasi YOK ve "Yakında" gosterir', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli))
          if (k.rota == null) k
      ];
      expect([for (final k in rotasiz) k.baslik], ['Araç Plaka', 'İhlaller']);
      expect([for (final k in rotasiz) k.altMetin], [_yakinda, _yakinda]);
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

    test('karsiligi olmayan kartlar: Otopark Kullanımı + İhlaller', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.yonetici))
          if (k.rota == null) k
      ];
      expect([for (final k in rotasiz) k.baslik],
          ['Otopark Kullanımı', 'İhlaller']);
      expect([for (final k in rotasiz) k.altMetin], [_yakinda, _yakinda]);
    });
  });
}
