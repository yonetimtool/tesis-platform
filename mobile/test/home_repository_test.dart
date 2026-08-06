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
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';

const _mock = MockHomeRepository();

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
          // Sabit metin YOK: ya sayac (null → iskelet) ya da ETIKET KIMLIGI.
          expect(
            k.altMetin == null,
            isTrue,
            reason: '${k.id.name} kartinda sabit sayac metni var: '
                '"${k.altMetin}"',
          );
        }
      });
    }

    test('yonetici Hızlı Özet: DORT kutunun tamami gercek uca bagli — hepsi '
        'DEGERSIZ baslar (otopark artik /parking/occupancy)', () {
      final kutular = _mock.ozet();
      expect([for (final k in kutular) k.id], [
        OzetKutuId.toplamDaire,
        OzetKutuId.toplamTahsilat,
        OzetKutuId.tahsilatOrani,
        OzetKutuId.otoparkDoluluk,
      ]);
      expect([for (final k in kutular) k.deger], [null, null, null, null]);
      expect(kutular.last.id, OzetKutuId.otoparkDoluluk);
    });
  });

  group('gorevli (security) — 4\'LU IZGARA: 8 kart, sirali', () {
    test('baslik sirasi: referans 5 kart + gunluk is kartlari', () {
      expect(
        [for (final k in _mock.hizliErisim(HomeVaryant.gorevli)) k.id],
        [
          HomeKartId.vardiyaDurum,
          HomeKartId.kargo,
          HomeKartId.ziyaretci,
          HomeKartId.aracPlaka,
          HomeKartId.ihlaller,
          HomeKartId.gorevlerim,
          HomeKartId.demirbas,
          HomeKartId.turlarim,
        ],
      );
    });

    test('8 kart = 4 sutunda TAM iki satir (dengeli izgara)', () {
      expect(_mock.hizliErisim(HomeVaryant.gorevli).length % 4, 0);
    });

    test('P8: ROTASIZ KART KALMADI — arac plaka + ihlaller ekranlari acildi',
        () {
      // Tur ~P8'e kadar bu iki kart "Bu bölüm yakında" diyordu (rota null).
      // Ekranlar yazilinca rotalandi; iddia TERSINE cevrildi ki kart yeniden
      // rotasiz birakilirsa test dussun.
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli))
          if (k.rota == null) k.id
      ];
      expect(rotasiz, isEmpty);
      final kartlar = {
        for (final k in _mock.hizliErisim(HomeVaryant.gorevli)) k.id: k
      };
      expect(kartlar[HomeKartId.aracPlaka]!.rota, '/arac-gecisleri');
      expect(kartlar[HomeKartId.ihlaller]!.rota, '/ihlaller');
      // Sabit metin YOK: sayac gercek uctan gelene kadar iskelet.
      expect(kartlar[HomeKartId.aracPlaka]!.altMetin, isNull);
      expect(kartlar[HomeKartId.ihlaller]!.altMetin, isNull);
    });
  });

  group('tesis gorevlisi — 4\'LU IZGARA: kendi is kartlari (KVKK)', () {
    final kartlar = _mock.hizliErisim(HomeVaryant.tesisGorevlisi);

    test('baslik sirasi', () {
      expect([for (final k in kartlar) k.id], [
        HomeKartId.vardiyaDurum,
        HomeKartId.gorevlerim,
        HomeKartId.demirbas,
        HomeKartId.talepAriza,
        HomeKartId.duyurular,
        HomeKartId.etkinlikler,
        HomeKartId.siteKurallari,
        HomeKartId.yonetici,
      ]);
    });

    test('KVKK: ziyaretci/kargo/plaka/ihlal kartlari HIC YOK — bu rolun '
        'ucleri 403 doner, kart kalici "—" gosterirdi', () {
      final idler = {for (final k in kartlar) k.id};
      for (final yasak in [
        HomeKartId.kargo,
        HomeKartId.ziyaretci,
        HomeKartId.aracPlaka,
        HomeKartId.ihlaller,
      ]) {
        expect(idler.contains(yasak), isFalse, reason: yasak.name);
      }
    });

    test('her kartin bir rotasi VAR (rotasiz/olu kart yok)', () {
      expect([for (final k in kartlar) if (k.rota == null) k.id], isEmpty);
    });

    test('8 kart = 4 sutunda TAM iki satir', () {
      expect(kartlar.length % 4, 0);
    });
  });

  group('site-sakini.jpeg — 4x2 izgara', () {
    test('8 kart, sira gorselle birebir', () {
      final kartlar = _mock.hizliErisim(HomeVaryant.sakin);
      // Kimlik sirasi (metin degil): baslik dile gore cozulur.
      expect(
        [for (final k in kartlar) k.id],
        [
          HomeKartId.ziyaretciler,
          HomeKartId.kargolarim,
          HomeKartId.aidatBilgileri,
          HomeKartId.geriBildirim,
          HomeKartId.sikayetlerim,
          HomeKartId.duyurular,
          HomeKartId.siteRaporlari,
        ],
      );
    });

    test('sakin izgarasinin TAMAMININ ucu var (rotasiz kart yok)', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.sakin))
          if (k.rota == null) k.id
      ];
      expect(rotasiz, isEmpty);
    });

    test('aidat kartinin iki satiri da gercek veriyi bekler', () {
      final aidat = _mock
          .hizliErisim(HomeVaryant.sakin)
          .firstWhere((k) => k.id == HomeKartId.aidatBilgileri);
      expect(aidat.altMetin, isNull);
      expect(aidat.ikinciAltMetin, isNull);
    });
  });

  group('yonetici.jpeg — 4x2 izgara', () {
    test('8 kart, sira gorselle birebir', () {
      expect(
        [for (final k in _mock.hizliErisim(HomeVaryant.yonetici)) k.id],
        [
          HomeKartId.vardiyaDurumu,
          HomeKartId.gorevler,
          HomeKartId.aidatDurumu,
          HomeKartId.otoparkKullanimi,
          HomeKartId.ihlaller,
          HomeKartId.geriBildirim,
          HomeKartId.sikayetler,
          HomeKartId.raporlar,
        ],
      );
    });

    test('P8: ROTASIZ KART KALMADI — Otopark + İhlaller ekranlari acildi', () {
      final rotasiz = [
        for (final k in _mock.hizliErisim(HomeVaryant.yonetici))
          if (k.rota == null) k.id
      ];
      expect(rotasiz, isEmpty);
      final kartlar = {
        for (final k in _mock.hizliErisim(HomeVaryant.yonetici)) k.id: k
      };
      // Yonetici PLAKA listesini goremez (KVKK) — AGREGAT otopark ekranina
      // gider; ihlalleri okur (ekran ona eylem dugmesi gostermez).
      expect(kartlar[HomeKartId.otoparkKullanimi]!.rota, '/otopark');
      expect(kartlar[HomeKartId.ihlaller]!.rota, '/ihlaller');
      expect(kartlar[HomeKartId.otoparkKullanimi]!.altMetin, isNull);
      expect(kartlar[HomeKartId.ihlaller]!.altMetin, isNull);
    });
  });
}
