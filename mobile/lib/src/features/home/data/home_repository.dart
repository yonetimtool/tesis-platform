/// Ana ekran bolumlerinin TABAN DUZENI (referans gorseller) + SOZLESMEDE
/// KARSILIGI OLMAYAN kartlarin metinleri.
///
/// Kural (tek cumle): **bu dosya UYDURMA SAYI URETMEZ.** Icerdigi tek sey
///   1. kart iskeleti — ikon / baslik / accent renk / rota (tasarim sabiti,
///      veri degil), ve
///   2. `contracts/openapi.yaml`'da KARSILIGI OLMAYAN kartlarin 'Yakında'
///      etiketi (her biri `// TODO(contract):` ile isaretli).
///
/// Gercek uca bagli her kartin sayaci `null` baslar: veri gelene kadar kart
/// iskelet cizer ([HomeSayacIskeleti]), veri gelince rol ekrani `sayacla` ile
/// GERCEK degeri yazar. Boylece ekranda hicbir an sahte sayi durmaz.
///
/// Alan → uc eslemesinin TAM tablosu README "Ana ekran veri eslemesi"
/// bolumundedir; oradaki MISSING satirlari ile buradaki `TODO(contract)`
/// isaretleri birebir ayni kumedir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/home_tokens.dart';
import '../../../routing/app_router.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';

/// Ana ekranin taban duzeni. SAF — Dio/provider bilmez, testte sahtelenir.
abstract class HomeRepository {
  /// Varyantin hizli erisim kartlari (gorevli: 5'li serit; digerleri 4x2).
  /// Gercek uca bagli kartlarin `altMetin`i null'dir (yukleniyor).
  List<HizliErisimKart> hizliErisim(HomeVaryant varyant);

  /// Yonetici "Hızlı Özet" kutulari (degerler null = yukleniyor).
  List<OzetKutusu> ozet();
}

/// Referans gorsellerin (docs/design-refs) DUZENI: ikon, baslik, renk, sira
/// ve rota gorsellerle birebir. Sayilar burada YOKTUR.
class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  @override
  List<HizliErisimKart> hizliErisim(HomeVaryant varyant) => switch (varyant) {
        HomeVaryant.gorevli => _gorevliErisim,
        HomeVaryant.sakin => _sakinErisim,
        HomeVaryant.yonetici => _yoneticiErisim,
      };

  /// gorevli.jpeg — TEK SIRA yatay serit, 5 kart.
  static const _gorevliErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.local_police,
      baslik: 'Vardiya Durum',
      accent: HomeTokens.primary,
      altMetin: null, // GET /shifts
      rota: AppRoutes.vardiyalar,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_2,
      baslik: 'Kargo',
      accent: HomeTokens.green,
      altMetin: null, // GET /kargo
      rota: AppRoutes.kargo,
    ),
    HizliErisimKart(
      ikon: Icons.person,
      baslik: 'Ziyaretçi',
      accent: HomeTokens.orange,
      altMetin: null, // GET /visitors
      rota: AppRoutes.visitors,
    ),
    // TODO(contract): plaka okuma/arac gecis ucu YOK — gecis kaydi, plaka,
    // gunluk giris sayaci hicbir semada gecmiyor. Oneri: GET /vehicle-passes.
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Araç Plaka',
      accent: HomeTokens.purple,
      altMetin: _yakinda,
      altMetinRengi: _gri,
    ),
    // TODO(contract): "ihlal" ucu YOK (kamera/kural ihlali kaydi). Site
    // kurallari (/site-rules) yalniz METIN tutar, ihlal kaydi tutmaz.
    // Oneri: GET /violations.
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      altMetin: _yakinda,
      altMetinRengi: _gri,
    ),
  ];

  /// site-sakini.jpeg — 4 sutun x 2 satir SABIT izgara.
  static const _sakinErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.person_outline,
      baslik: 'Ziyaretçiler',
      accent: HomeTokens.purple,
      altMetin: null, // GET /visitors (yalniz kendine hedeflenenler)
      altMetinRengi: _gri,
      rota: AppRoutes.visitors,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_2,
      baslik: 'Kargolarım',
      accent: HomeTokens.green,
      altMetin: null, // GET /kargo (kendi dairesi)
      altMetinRengi: _gri,
      rota: AppRoutes.kargo,
    ),
    HizliErisimKart(
      ikon: Icons.account_balance_wallet,
      baslik: 'Aidat Bilgileri',
      accent: HomeTokens.primary,
      altMetin: null, // GET /me/dues
      altMetinRengi: _gri,
      ikinciAltMetin: null, // GET /me/dues → bakiye
      ikinciAltMetinRengi: HomeTokens.green,
      rota: AppRoutes.myDues,
    ),
    HizliErisimKart(
      ikon: Icons.graphic_eq,
      baslik: 'Gürültü Şikayeti',
      accent: HomeTokens.red,
      // Sayac degil EYLEM etiketi (POST /unit-complaints) — sabit metin.
      altMetin: 'Bildirim Yap',
      altMetinRengi: _gri,
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.campaign,
      baslik: 'Geri Bildirim',
      accent: HomeTokens.orange,
      altMetin: null, // GET /complaints?durum=acik (kendi actiklari)
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.description_outlined,
      baslik: 'Şikayetlerim',
      accent: HomeTokens.primary,
      altMetin: null, // GET /unit-complaints/mine?durum=acik
      altMetinRengi: _gri,
      rota: AppRoutes.sikayetlerim,
    ),
    HizliErisimKart(
      ikon: Icons.info,
      baslik: 'Duyurular',
      accent: HomeTokens.purple,
      altMetin: null, // GET /announcements
      rota: AppRoutes.announcements,
    ),
    HizliErisimKart(
      ikon: Icons.bar_chart,
      baslik: 'Site Raporları',
      accent: HomeTokens.primary,
      // Sayac degil bolum etiketi (GET /reports/financial-summary ekrani).
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
      altMetin: null, // GET /shifts
      rota: AppRoutes.vardiyalar,
    ),
    HizliErisimKart(
      ikon: Icons.assignment_turned_in_outlined,
      baslik: 'Görevler',
      accent: HomeTokens.green,
      altMetin: null, // GET /tasks?aktif=true → meta.total
      altMetinRengi: _gri,
      rota: '${AppRoutes.tasks}?gorunum=yonetim',
    ),
    HizliErisimKart(
      ikon: Icons.description_outlined,
      baslik: 'Aidat Durumu',
      accent: HomeTokens.orange,
      // GET /reports/financial-summary → tahsilat.geciken_daire_sayisi
      altMetin: null,
      altMetinRengi: _gri,
      rota: AppRoutes.financialSummary,
    ),
    // TODO(contract): otopark ucu YOK (kapasite/doluluk/park yeri). Oneri:
    // GET /parking/occupancy.
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Otopark Kullanımı',
      accent: HomeTokens.purple,
      altMetin: _yakinda,
      altMetinRengi: _gri,
    ),
    // TODO(contract): ihlal ucu YOK (bkz. gorevli seridi).
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      altMetin: _yakinda,
      altMetinRengi: _gri,
    ),
    HizliErisimKart(
      ikon: Icons.mode_comment_outlined,
      baslik: 'Geri Bildirim',
      accent: HomeTokens.orange,
      altMetin: null, // GET /complaints?durum=acik → meta.total
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.campaign_outlined,
      baslik: 'Şikayetler',
      accent: HomeTokens.purple,
      altMetin: null, // GET /unit-complaints?durum=acik → meta.total
      rota: AppRoutes.sikayetHaritasi,
    ),
    HizliErisimKart(
      ikon: Icons.bar_chart,
      baslik: 'Raporlar',
      accent: HomeTokens.primary,
      altMetin: 'Aylık Özet', // bolum etiketi, sayac degil
      altMetinRengi: _gri,
      rota: AppRoutes.reports,
    ),
  ];

  @override
  List<OzetKutusu> ozet() => const [
        OzetKutusu(
          ikon: Icons.groups,
          deger: null, // GET /units?limit=1 → meta.total
          etiket: 'Toplam Daire',
          altEtiket: 'Tüm Site',
          accent: HomeTokens.primary,
        ),
        OzetKutusu(
          ikon: Icons.paid_outlined,
          deger: null, // GET /reports/financial-summary → tahsilat_kurus
          etiket: 'Toplam Tahsilat',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.green,
        ),
        OzetKutusu(
          ikon: Icons.percent,
          deger: null, // .. → tahsilat_orani_yuzde
          etiket: 'Aidat Tahsilat Oranı',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.orange,
        ),
        // TODO(contract): otopark doluluk ucu YOK — kapasite de doluluk da
        // hicbir semada gecmiyor. Oneri: GET /parking/occupancy.
        OzetKutusu(
          ikon: Icons.directions_car,
          deger: _bos,
          etiket: 'Otopark Doluluk',
          altEtiket: _yakinda,
          accent: HomeTokens.purple,
        ),
      ];
}

/// Referans gorsellerde ACIKLAMA alt metinleri gridir (sayac degil).
const _gri = Color(0xFF6B7280);

/// Sozlesmede karsiligi olmayan kartin sayac satiri — sayi YERINE bu durur.
const _yakinda = 'Yakında';

/// Sozlesmede karsiligi olmayan istatistik kutusunun degeri.
const _bos = '—';

/// Ana ekran taban duzeni. Testte `overrideWithValue` ile degistirilebilir.
final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => const MockHomeRepository());
