/// Ana ekran bolumlerinin VERI KAPISI.
///
/// Referans gorsellerdeki bolumlerin bir kisminin backend'de karsiligi YOK
/// (arac plaka, ihlaller, otopark doluluk, "ziyaretçi içeride" sayaci,
/// hava/duyuru gorseli...). Bunlar icin uc UYDURULMAZ: hepsi bu arayuzun
/// arkasindadir ve [MockHomeRepository] referans gorsellerdeki DEGERLERIN
/// AYNISINI dondurur.
///
/// Kural (tek cumle): **mock TABANDIR, gercek API verisi geldiginde onun
/// uzerine YAZAR.** Rol ekranlari once bu tabani alir, sonra elindeki gercek
/// provider degerleriyle ilgili alanlari degistirir. Boylece:
///   * gercek uc varsa kullanici GERCEK veriyi gorur,
///   * gercek uc yoksa/bosken ekran referans duzeninde durur (bos beyaz
///     ekran yok),
///   * "hangi alan gercek, hangisi mock" TEK dosyadan okunur.
///
/// Gercek uca baglanacak alanlarin listesi README "TODO: gerçek uç"
/// bolumundedir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/home_tokens.dart';
import '../../../routing/app_router.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';

/// Ana ekranin ihtiyac duydugu tum bolum verisi. SAF — Dio/provider bilmez,
/// testte kolayca sahtelenir.
abstract class HomeRepository {
  /// Baslik hava blogu (MISSING-BACKEND degil: /weather var — bu yalniz
  /// yukleme/hata anindaki taban).
  HomeHava hava();

  /// Varyantin hizli erisim kartlari (gorevli: 5'li serit; digerleri 4x2).
  List<HizliErisimKart> hizliErisim(HomeVaryant varyant);

  /// Varyantin "Son Hareketler" satirlari.
  List<HareketSatiri> hareketler(HomeVaryant varyant);

  /// Vardiya seridi (gorevli + yonetici).
  List<VardiyaKart> vardiyalar();

  /// Yonetici "Hızlı Özet" kutulari.
  List<OzetKutusu> ozet();

  /// Sakin "Ödeme ve Aidat Durumu".
  OdemeOzeti odeme();

  /// Sakin duyuru karti.
  DuyuruOzeti duyuru();

  /// Gorevli canli kamera seridi.
  List<KameraOzeti> kameralar();

  /// Gorevli baslik alt satirindaki tesis adi ("Mavi Residence ⌄").
  String tesisAd();

  /// Sakin baslik alt satiri ("Daire 12, A Blok  •  Kat Maliki").
  String sakinAltBaslik();

  /// Vardiya seridindeki yonetici kartinin adi.
  String yoneticiAd();
}

/// Referans gorsellerin (docs/design-refs) DEGERLERI. Metinler, sayilar,
/// renkler ve sira gorsellerle birebir; degistirilirse ana ekran referanstan
/// sapar.
class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  @override
  HomeHava hava() => const HomeHava(
        sicaklik: '24°C',
        sehir: 'İstanbul',
        ikon: Icons.wb_sunny_outlined,
      );

  @override
  String tesisAd() => 'Mavi Residence';

  @override
  String sakinAltBaslik() => 'Daire 12, A Blok  •  Kat Maliki';

  @override
  String yoneticiAd() => 'Kerem Aşçı';

  // ------------------------------------------------------------ hizli erisim
  @override
  List<HizliErisimKart> hizliErisim(HomeVaryant varyant) => switch (varyant) {
        HomeVaryant.gorevli => _gorevliErisim,
        HomeVaryant.sakin => _sakinErisim,
        HomeVaryant.yonetici => _yoneticiErisim,
      };

  /// gorevli.jpeg — TEK SIRA yatay serit, 5 kart; alt metinler accent renkte.
  static const _gorevliErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.local_police,
      baslik: 'Vardiya Durum',
      accent: HomeTokens.primary,
      altMetin: '3 Aktif',
      rota: AppRoutes.vardiyalar,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_2,
      baslik: 'Kargo',
      accent: HomeTokens.green,
      altMetin: '5 Bekliyor',
      rota: AppRoutes.kargo,
    ),
    HizliErisimKart(
      ikon: Icons.person,
      baslik: 'Ziyaretçi',
      accent: HomeTokens.orange,
      altMetin: '2 İçeride',
      rota: AppRoutes.visitors,
    ),
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Araç Plaka',
      accent: HomeTokens.purple,
      altMetin: '8 Giriş',
    ),
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      altMetin: '4 Yeni',
    ),
  ];

  /// site-sakini.jpeg — 4 sutun x 2 satir SABIT izgara. Sayaclar gri,
  /// vurgulu olanlar (2 Yeni / 3 Yeni / Borç Yok) renkli — gorseldeki gibi.
  static const _sakinErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.person_outline,
      baslik: 'Ziyaretçiler',
      accent: HomeTokens.purple,
      altMetin: '2 Bekliyor',
      altMetinRengi: _gri,
      rota: AppRoutes.visitors,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_2,
      baslik: 'Kargolarım',
      accent: HomeTokens.green,
      altMetin: '1 Bekliyor',
      altMetinRengi: _gri,
      rota: AppRoutes.kargo,
    ),
    HizliErisimKart(
      ikon: Icons.account_balance_wallet,
      baslik: 'Aidat Bilgileri',
      accent: HomeTokens.primary,
      altMetin: '₺1.250,00',
      altMetinRengi: _gri,
      ikinciAltMetin: 'Borç Yok',
      ikinciAltMetinRengi: HomeTokens.green,
      rota: AppRoutes.myDues,
    ),
    HizliErisimKart(
      ikon: Icons.graphic_eq,
      baslik: 'Gürültü Şikayeti',
      accent: HomeTokens.red,
      altMetin: 'Bildirim Yap',
      altMetinRengi: _gri,
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.campaign,
      baslik: 'Geri Bildirim',
      accent: HomeTokens.orange,
      altMetin: '2 Yeni',
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.description_outlined,
      baslik: 'Şikayetlerim',
      accent: HomeTokens.primary,
      altMetin: '1 Açık',
      altMetinRengi: _gri,
      rota: AppRoutes.sikayetlerim,
    ),
    HizliErisimKart(
      ikon: Icons.info,
      baslik: 'Duyurular',
      accent: HomeTokens.purple,
      altMetin: '3 Yeni',
      rota: AppRoutes.announcements,
    ),
    HizliErisimKart(
      ikon: Icons.bar_chart,
      baslik: 'Site Raporları',
      accent: HomeTokens.primary,
      altMetin: 'Aylık Özet',
      altMetinRengi: _gri,
      rota: AppRoutes.transparency,
    ),
  ];

  /// yonetici.jpeg — 4x2 SABIT izgara.
  static const _yoneticiErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.local_police,
      baslik: 'Vardiya Durumu',
      accent: HomeTokens.primary,
      altMetin: '4 Aktif',
      rota: AppRoutes.vardiyalar,
    ),
    HizliErisimKart(
      ikon: Icons.assignment_turned_in_outlined,
      baslik: 'Görevler',
      accent: HomeTokens.green,
      altMetin: '6 Bekliyor',
      altMetinRengi: _gri,
      rota: '${AppRoutes.tasks}?gorunum=yonetim',
    ),
    HizliErisimKart(
      ikon: Icons.description_outlined,
      baslik: 'Aidat Durumu',
      accent: HomeTokens.orange,
      altMetin: '104 Daire',
      altMetinRengi: _gri,
      rota: AppRoutes.financialSummary,
    ),
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Otopark Kullanımı',
      accent: HomeTokens.purple,
      altMetin: '78 / 120',
      altMetinRengi: HomeTokens.primary,
    ),
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      altMetin: '5 Yeni',
    ),
    HizliErisimKart(
      ikon: Icons.mode_comment_outlined,
      baslik: 'Geri Bildirim',
      accent: HomeTokens.orange,
      altMetin: '8 Yeni',
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.campaign_outlined,
      baslik: 'Şikayetler',
      accent: HomeTokens.purple,
      altMetin: '3 Yeni',
      rota: AppRoutes.sikayetHaritasi,
    ),
    HizliErisimKart(
      ikon: Icons.bar_chart,
      baslik: 'Raporlar',
      accent: HomeTokens.primary,
      altMetin: 'Aylık Özet',
      altMetinRengi: _gri,
      rota: AppRoutes.reports,
    ),
  ];

  // -------------------------------------------------------------- hareketler
  @override
  List<HareketSatiri> hareketler(HomeVaryant varyant) => switch (varyant) {
        HomeVaryant.gorevli => _gorevliHareket,
        HomeVaryant.sakin => _sakinHareket,
        HomeVaryant.yonetici => _yoneticiHareket,
      };

  static const _gorevliHareket = <HareketSatiri>[
    HareketSatiri(
      ikon: Icons.error_outline,
      baslik: 'Kamera İhlal Tespiti',
      altBaslik: 'Otopark Girişi - Kamera 3',
      zaman: '09:32',
      ikonAccent: HomeTokens.red,
      noktaRengi: HomeTokens.red,
    ),
    HareketSatiri(
      ikon: Icons.sensor_door_outlined,
      baslik: 'Kapı Açıldı',
      altBaslik: 'A Blok - Ana Giriş',
      zaman: '09:21',
      ikonAccent: HomeTokens.green,
      noktaRengi: HomeTokens.green,
    ),
    HareketSatiri(
      ikon: Icons.directions_car,
      baslik: 'Araç Girişi',
      altBaslik: '34 ABC 123 - BMW Siyah',
      zaman: '09:15',
      ikonAccent: HomeTokens.primary,
      noktaRengi: HomeTokens.primary,
    ),
    HareketSatiri(
      ikon: Icons.inventory_2_outlined,
      baslik: 'Kargo Teslim Alındı',
      altBaslik: 'Mng Kargo - 245781236',
      zaman: '09:05',
      ikonAccent: HomeTokens.orange,
      noktaRengi: HomeTokens.orange,
    ),
    HareketSatiri(
      ikon: Icons.person_outline,
      baslik: 'Ziyaretçi Girişi',
      altBaslik: 'Ahmet Yılmaz - Daire 15',
      zaman: '08:58',
      ikonAccent: HomeTokens.purple,
      noktaRengi: HomeTokens.purple,
    ),
  ];

  static const _sakinHareket = <HareketSatiri>[
    HareketSatiri(
      ikon: Icons.person_outline,
      baslik: 'Ziyaretçi Girişi',
      altBaslik: 'Ahmet Yılmaz - Daire 15',
      zaman: 'Bugün 10:15',
      ikonAccent: HomeTokens.purple,
      noktaRengi: HomeTokens.purple,
    ),
    HareketSatiri(
      ikon: Icons.inventory_2_outlined,
      baslik: 'Kargo Teslim Edildi',
      altBaslik: 'Mng Kargo - 245781236',
      zaman: 'Bugün 09:47',
      ikonAccent: HomeTokens.green,
      noktaRengi: HomeTokens.green,
    ),
    HareketSatiri(
      // Gorselde ikon KIRMIZI ses dalgasi (modulun rengi), nokta TURUNCU
      // (olayin durum rengi) — ikisi bilincli olarak ayri.
      ikon: Icons.graphic_eq,
      baslik: 'Gürültü Şikayeti Bildirimi',
      altBaslik: 'Akşam 22:30 – Müzik Sesi',
      zaman: 'Dün 22:35',
      ikonAccent: HomeTokens.red,
      noktaRengi: HomeTokens.orange,
    ),
    HareketSatiri(
      ikon: Icons.campaign,
      baslik: 'Geri Bildirim',
      altBaslik: 'Asansör temizliği hakkında',
      zaman: 'Dün 15:20',
      ikonAccent: HomeTokens.orange,
      noktaRengi: HomeTokens.purple,
    ),
    HareketSatiri(
      ikon: Icons.account_balance_wallet,
      baslik: 'Aidat Ödemesi',
      altBaslik: 'Mayıs 2026 - Ödeme Yapıldı',
      zaman: '05.05.2026',
      ikonAccent: HomeTokens.primary,
      noktaRengi: HomeTokens.green,
    ),
  ];

  static const _yoneticiHareket = <HareketSatiri>[
    HareketSatiri(
      ikon: Icons.error_outline,
      baslik: 'Kamera İhlal Tespiti',
      altBaslik: 'Otopark Girişi - Kamera 3',
      zaman: '09:32',
      ikonAccent: HomeTokens.red,
      noktaRengi: HomeTokens.red,
    ),
    HareketSatiri(
      ikon: Icons.sensor_door_outlined,
      baslik: 'Kapı Açıldı',
      altBaslik: 'A Blok - Ana Giriş',
      zaman: '09:21',
      ikonAccent: HomeTokens.green,
      noktaRengi: HomeTokens.green,
    ),
    HareketSatiri(
      ikon: Icons.description_outlined,
      baslik: 'Aidat Ödemesi',
      altBaslik: 'Daire 15 - Aylık Ödeme',
      zaman: '09:15',
      ikonAccent: HomeTokens.orange,
      noktaRengi: HomeTokens.primary,
    ),
    HareketSatiri(
      ikon: Icons.mode_comment_outlined,
      baslik: 'Yeni Şikayet',
      altBaslik: 'Gürültü şikayeti - Daire 22',
      zaman: '08:58',
      ikonAccent: HomeTokens.purple,
      noktaRengi: HomeTokens.purple,
    ),
  ];

  // ----------------------------------------------------------------- vardiya
  @override
  List<VardiyaKart> vardiyalar() => const [
        VardiyaKart(
          baslik: 'Sabah Vardiyası',
          altBaslik: '06:00 - 14:00',
          durum: VardiyaDurum.aktif,
          altBilgi: '2 Görevli',
          online: false,
        ),
        VardiyaKart(
          baslik: 'Öğle Vardiyası',
          altBaslik: '14:00 - 22:00',
          durum: VardiyaDurum.aktif,
          altBilgi: '2 Görevli',
        ),
        VardiyaKart(
          baslik: 'Gece Vardiyası',
          altBaslik: '22:00 - 06:00',
          durum: VardiyaDurum.planlandi,
          altBilgi: '2 Görevli',
        ),
        VardiyaKart(
          baslik: 'Yönetici',
          altBaslik: 'Kerem Aşçı',
          durum: VardiyaDurum.yonetici,
          altBilgi: 'Online',
          online: true,
        ),
      ];

  // ------------------------------------------------------------- hizli ozet
  @override
  List<OzetKutusu> ozet() => const [
        OzetKutusu(
          ikon: Icons.groups,
          deger: '512',
          etiket: 'Toplam Daire',
          altEtiket: 'Tüm Site',
          accent: HomeTokens.primary,
        ),
        OzetKutusu(
          ikon: Icons.paid_outlined,
          deger: '₺248.750',
          etiket: 'Toplam Tahsilat',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.green,
        ),
        OzetKutusu(
          ikon: Icons.percent,
          deger: '%86',
          etiket: 'Aidat Tahsilat Oranı',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.orange,
        ),
        OzetKutusu(
          ikon: Icons.directions_car,
          deger: '78 / 120',
          etiket: 'Otopark Doluluk',
          altEtiket: '%65',
          accent: HomeTokens.purple,
        ),
      ];

  // ------------------------------------------------------------------- sakin
  @override
  OdemeOzeti odeme() => const OdemeOzeti(
        buAyTutar: '₺1.250,00',
        odendi: true,
        sonOdeme: '05.05.2026',
        gelecekTarih: '05.06.2026',
        gelecekTutar: '₺1.250,00',
      );

  @override
  DuyuruOzeti duyuru() => const DuyuruOzeti(
        baslik: 'Bahçe Düzenlemesi',
        govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
        tarih: '20 Mayıs – 09:00',
        yeni: true,
      );

  // ---------------------------------------------------------------- kameralar
  @override
  List<KameraOzeti> kameralar() => const [
        KameraOzeti(ad: 'Ana Giriş'),
        KameraOzeti(ad: 'Otopark'),
        KameraOzeti(ad: 'Arka Bahçe'),
        KameraOzeti(ad: 'B Blok Girişi'),
      ];
}

/// Referans gorsellerde ACIKLAMA alt metinleri gridir (sayac degil).
const _gri = Color(0xFF6B7280);

/// Ana ekran taban verisi. Testte `overrideWithValue` ile degistirilebilir.
final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => const MockHomeRepository());
