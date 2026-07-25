/// Ana ekran bolumlerinin TABAN DUZENI (referans gorseller).
///
/// Kural (tek cumle): **bu dosya UYDURMA SAYI URETMEZ.** Icerdigi tek sey kart
/// iskeleti — ikon / baslik / accent renk / rota (tasarim sabiti, veri degil).
///
/// G1-G7 kapandiktan sonra (backend `bf1dc84`) izgaralarda SOZLESME BOSLUGU
/// KALMADI: her sayacin bir ucu var, bu yuzden 'Yakında' etiketi ve
/// `TODO(contract)` isaretleri kaldirildi. Sayac degil ETIKET tasiyan iki kart
/// ("Aylık Özet") sabit metnini korur — onlar sayac degildir.
///
/// Gercek uca bagli her kartin sayaci `null` baslar: veri gelene kadar kart
/// iskelet cizer ([HomeSayacIskeleti]), veri gelince rol ekrani `sayacla` ile
/// GERCEK degeri yazar. Boylece ekranda hicbir an sahte sayi durmaz.
///
/// Alan → uc eslemesinin TAM tablosu README "Ana ekran veri eslemesi"
/// bolumundedir.
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
        HomeVaryant.tesisGorevlisi => _tesisGorevlisiErisim,
        HomeVaryant.sakin => _sakinErisim,
        HomeVaryant.yonetici => _yoneticiErisim,
      };

  /// gorevli.jpeg duzeni 4'LU IZGARAYA tasindi (yonetici izgarasiyla ayni
  /// kart tipi/olcusu): 8 kart = 4x2 dengeli iki satir. Serit 5 kartta
  /// kaliyordu ve "Görevlerim"/"Demirbaş" gibi gunluk isler menude gizliydi.
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
      altMetin: null, // GET /visitors?icerde=true → meta.total
      rota: AppRoutes.visitors,
    ),
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Araç Plaka',
      accent: HomeTokens.purple,
      // GET /vehicle-passes?baslangic=<gun basi> → meta.total ("N Giriş").
      // Liste/detay ekrani henuz yok → rota null (dokununca "yakında").
      altMetin: null,
    ),
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      // GET /violations?durum=yeni → meta.total ("N Yeni").
      // Liste ekrani yok → rotasiz.
      altMetin: null,
    ),
    // Saha personelinin GUNLUK isleri: gorev + zimmet + devriye. Bunlar
    // eskiden yalniz cekmecede duruyordu; izgaraya cikti.
    HizliErisimKart(
      ikon: Icons.task_alt,
      baslik: 'Görevlerim',
      accent: HomeTokens.green,
      altMetin: null, // GET /tasks?aktif=true → meta.total
      rota: AppRoutes.tasks,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_outlined,
      baslik: 'Demirbaş',
      accent: HomeTokens.orange,
      altMetin: null, // GET /assets?checked_out_by=me → meta.total
      rota: AppRoutes.assets,
    ),
    HizliErisimKart(
      ikon: Icons.directions_walk,
      baslik: 'Turlarım',
      accent: HomeTokens.primary,
      // Devriye penceresi sayaci ana ekranda yok (ekran kendi durumunu
      // gosterir) — sayac degil BOLUM etiketi.
      altMetin: 'Devriye',
      altMetinRengi: _gri,
      rota: AppRoutes.patrol,
    ),
  ];

  /// Tesis gorevlisi izgarasi — KVKK: ziyaretci/kargo/plaka/ihlal/kamera
  /// yonetimi YOK. Yalniz bu rolun cagirabildigi uclar (auth.md §4):
  /// /shifts, /tasks, /assets, /complaints, /announcements, /events,
  /// /site-rules, /yonetici-iletisim.
  static const _tesisGorevlisiErisim = <HizliErisimKart>[
    HizliErisimKart(
      ikon: Icons.local_police,
      baslik: 'Vardiya Durum',
      accent: HomeTokens.primary,
      altMetin: null, // GET /shifts
      rota: AppRoutes.vardiyalar,
    ),
    HizliErisimKart(
      ikon: Icons.task_alt,
      baslik: 'Görevlerim',
      accent: HomeTokens.green,
      altMetin: null, // GET /tasks?aktif=true → meta.total
      rota: AppRoutes.tasks,
    ),
    HizliErisimKart(
      ikon: Icons.inventory_outlined,
      baslik: 'Demirbaş',
      accent: HomeTokens.orange,
      altMetin: null, // GET /assets?checked_out_by=me → meta.total
      rota: AppRoutes.assets,
    ),
    HizliErisimKart(
      ikon: Icons.rate_review_outlined,
      baslik: 'Talep / Arıza',
      accent: HomeTokens.red,
      altMetin: null, // GET /complaints?durum=acik → meta.total (kendi actiklari)
      rota: AppRoutes.complaints,
    ),
    HizliErisimKart(
      ikon: Icons.info,
      baslik: 'Duyurular',
      accent: HomeTokens.purple,
      altMetin: null, // GET /announcements → son 3 gun
      rota: AppRoutes.announcements,
    ),
    HizliErisimKart(
      ikon: Icons.event_available_outlined,
      baslik: 'Etkinlikler',
      accent: HomeTokens.green,
      altMetin: null, // GET /events?aktif=true → meta.total
      rota: AppRoutes.etkinlik,
    ),
    HizliErisimKart(
      ikon: Icons.menu_book_outlined,
      baslik: 'Site Kuralları',
      accent: HomeTokens.primary,
      // Sayac degil bolum etiketi (kural listesi).
      altMetin: 'Kurallar',
      altMetinRengi: _gri,
      rota: AppRoutes.siteKurallari,
    ),
    HizliErisimKart(
      ikon: Icons.support_agent_outlined,
      baslik: 'Yönetici',
      accent: HomeTokens.orange,
      altMetin: 'İletişim',
      altMetinRengi: _gri,
      rota: AppRoutes.yoneticiIletisim,
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
      // G6: GET /unit-complaints/mine?kategori=gurultu&durum=acik → meta.total
      // ("N Açık"). Kart dokunulunca hala BILDIRIM akisina gider.
      altMetin: null,
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
    HizliErisimKart(
      ikon: Icons.directions_car,
      baslik: 'Otopark Kullanımı',
      accent: HomeTokens.purple,
      // GET /parking/occupancy → "dolu / kapasite" (kapasite yoksa "N araç").
      altMetin: null,
    ),
    HizliErisimKart(
      ikon: Icons.error_outline,
      baslik: 'İhlaller',
      accent: HomeTokens.red,
      altMetin: null, // GET /violations?durum=yeni → meta.total
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
          // Daire listesi/duzenlemesi: blok → kat → daire editoru.
          rota: AppRoutes.binaDuzenleme,
        ),
        OzetKutusu(
          ikon: Icons.paid_outlined,
          deger: null, // GET /reports/financial-summary → tahsilat_kurus
          etiket: 'Toplam Tahsilat',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.green,
          rota: AppRoutes.financialSummary,
        ),
        OzetKutusu(
          ikon: Icons.percent,
          deger: null, // .. → tahsilat_orani_yuzde
          etiket: 'Aidat Tahsilat Oranı',
          altEtiket: 'Bu Ay',
          accent: HomeTokens.orange,
          // Ayni yanittan beslenen tahsilat raporu ekrani.
          rota: AppRoutes.financialSummary,
        ),
        // GET /parking/occupancy → `oran` ("%2"); kapasite tanimsizsa sunucu
        // oran'i null doner → kutu '—' gosterir (uydurma yuzde YOK).
        //
        // ROTA YOK: mobilde arac gecisi/otopark EKRANI henuz yok (sayac var,
        // liste yok). Dokunma "yakında" bilgilendirmesi verir; uydurma bir
        // hedefe (orn. kameralar) yonlendirmek yanlis olurdu.
        OzetKutusu(
          ikon: Icons.directions_car,
          deger: null,
          etiket: 'Otopark Doluluk',
          altEtiket: 'Şu An',
          accent: HomeTokens.purple,
        ),
      ];
}

/// Referans gorsellerde ACIKLAMA alt metinleri gridir (sayac degil).
const _gri = Color(0xFF6B7280);

/// Ana ekran taban duzeni. Testte `overrideWithValue` ile degistirilebilir.
final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => const MockHomeRepository());
