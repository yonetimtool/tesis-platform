import 'package:flutter/material.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../../routing/app_router.dart';
import '../domain/home_menu.dart';

/// Menu girisinin ana-ekran kart sunumu: ikon + baslik + kategori vurgu rengi
/// + gidilecek rota. TEK KAYNAK — tum rol ekranlari (R1/R2/R3) bunu kullanir;
/// ikon/baslik/rota eskiden home_screen._tileData'daydi, buraya tasindi.
class ModuleCardSpec {
  const ModuleCardSpec({
    required this.icon,
    required this.title,
    required this.accent,
    required this.route,
  });

  final IconData icon;
  final String title;
  final Color accent;

  /// go_router konumu (query dahil olabilir, or. "/tasks?gorunum=yonetim").
  final String route;
}

// Kategori pastel paleti (referans hissi). Marka navy/teal one cikar; digerleri
// anlam tasir: para=teal, sosyal/duyuru=amber, sikayet=mor, guvenlik=navy,
// lojistik/gorev=yesil, uyari=kirmizi.
const _navy = YonetioColors.navy;
const _teal = YonetioColors.teal;
const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _purple = Color(0xFF7C3AED);

/// Girise gore kart sunumu. Switch enum'da EKSIKSIZDIR (default yok) → yeni
/// giris eklenince derleyici burayi zorlar.
ModuleCardSpec moduleCardSpec(HomeMenuEntry entry) {
  switch (entry) {
    case HomeMenuEntry.announcements:
      return const ModuleCardSpec(
          icon: Icons.campaign_outlined,
          title: 'Duyurular',
          accent: _amber,
          route: AppRoutes.announcements);
    case HomeMenuEntry.patrol:
      return const ModuleCardSpec(
          icon: Icons.directions_walk,
          title: 'Turlarım',
          accent: _navy,
          route: AppRoutes.patrol);
    case HomeMenuEntry.patrolTracking:
      return const ModuleCardSpec(
          icon: Icons.route_outlined,
          title: 'Devriye Takibi',
          accent: _navy,
          route: AppRoutes.patrolTracking);
    case HomeMenuEntry.tasks:
      return const ModuleCardSpec(
          icon: Icons.task_alt,
          title: 'Görevlerim',
          accent: _green,
          route: AppRoutes.tasks);
    case HomeMenuEntry.taskTracking:
      return const ModuleCardSpec(
          icon: Icons.fact_check_outlined,
          title: 'Görev Yönetimi',
          accent: _green,
          route: '${AppRoutes.tasks}?gorunum=yonetim');
    case HomeMenuEntry.assets:
      return const ModuleCardSpec(
          icon: Icons.inventory_2_outlined,
          title: 'Demirbaş',
          accent: _green,
          route: AppRoutes.assets);
    case HomeMenuEntry.nfc:
      return const ModuleCardSpec(
          icon: Icons.nfc,
          title: 'NFC Okutma',
          accent: _navy,
          route: AppRoutes.nfc);
    case HomeMenuEntry.outbox:
      return const ModuleCardSpec(
          icon: Icons.outbox_outlined,
          title: 'Gönderim Kuyruğu',
          accent: _navy,
          route: AppRoutes.outbox);
    case HomeMenuEntry.reports:
      return const ModuleCardSpec(
          icon: Icons.insights_outlined,
          title: 'Aylık Raporlar',
          accent: _teal,
          route: AppRoutes.reports);
    case HomeMenuEntry.budget:
      return const ModuleCardSpec(
          icon: Icons.savings_outlined,
          title: 'Bütçe',
          accent: _teal,
          route: AppRoutes.budget);
    case HomeMenuEntry.financialSummary:
      return const ModuleCardSpec(
          icon: Icons.query_stats_outlined,
          title: 'Finansal Özet',
          accent: _teal,
          route: AppRoutes.financialSummary);
    case HomeMenuEntry.transparency:
      return const ModuleCardSpec(
          icon: Icons.insights_outlined,
          title: 'Şeffaflık',
          accent: _teal,
          route: AppRoutes.transparency);
    case HomeMenuEntry.siteBudget:
      return const ModuleCardSpec(
          icon: Icons.pie_chart_outline,
          title: 'Site Bütçesi',
          accent: _teal,
          route: AppRoutes.siteBudget);
    case HomeMenuEntry.myDues:
      return const ModuleCardSpec(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Aidatım',
          accent: _teal,
          route: AppRoutes.myDues);
    case HomeMenuEntry.complaints:
      return const ModuleCardSpec(
          icon: Icons.rate_review_outlined,
          title: 'Şikayet / Öneri',
          accent: _purple,
          route: AppRoutes.complaints);
    case HomeMenuEntry.visitors:
      return const ModuleCardSpec(
          icon: Icons.emoji_people_outlined,
          title: 'Ziyaretçiler',
          accent: _navy,
          route: AppRoutes.visitors);
    case HomeMenuEntry.kargo:
      return const ModuleCardSpec(
          icon: Icons.local_shipping_outlined,
          title: 'Kargo',
          accent: _green,
          route: AppRoutes.kargo);
    case HomeMenuEntry.unitAccess:
      return const ModuleCardSpec(
          icon: Icons.key_outlined,
          title: 'Görüntüleme İzni',
          accent: _navy,
          route: AppRoutes.unitAccess);
    case HomeMenuEntry.rezervasyon:
      return const ModuleCardSpec(
          icon: Icons.event_available_outlined,
          title: 'Rezervasyon',
          accent: _navy,
          route: AppRoutes.rezervasyon);
    case HomeMenuEntry.etkinlik:
      return const ModuleCardSpec(
          icon: Icons.celebration_outlined,
          title: 'Etkinlikler',
          accent: _amber,
          route: AppRoutes.etkinlik);
    case HomeMenuEntry.siteKurallari:
      return const ModuleCardSpec(
          icon: Icons.gavel_outlined,
          title: 'Site Kuralları',
          accent: _amber,
          route: AppRoutes.siteKurallari);
    case HomeMenuEntry.disHizmet:
      return const ModuleCardSpec(
          icon: Icons.handyman_outlined,
          title: 'Dış Hizmetler',
          accent: _amber,
          route: AppRoutes.disHizmet);
    case HomeMenuEntry.integrations:
      return const ModuleCardSpec(
          icon: Icons.hub_outlined,
          title: 'Entegrasyonlar',
          accent: _navy,
          route: AppRoutes.integrations);
    case HomeMenuEntry.personel:
      return const ModuleCardSpec(
          icon: Icons.badge_outlined,
          title: 'Saha Personeli',
          accent: _navy,
          route: AppRoutes.personel);
    case HomeMenuEntry.sakinler:
      return const ModuleCardSpec(
          icon: Icons.people_alt_outlined,
          title: 'Site Sakinleri',
          accent: _navy,
          route: AppRoutes.sakinler);
    case HomeMenuEntry.binaDuzenleme:
      return const ModuleCardSpec(
          icon: Icons.apartment_outlined,
          title: 'Bina Yapısı',
          accent: _navy,
          route: AppRoutes.binaDuzenleme);
    case HomeMenuEntry.sikayetHaritasi:
      return const ModuleCardSpec(
          icon: Icons.grid_view_outlined,
          title: 'Şikayet Haritası',
          accent: _purple,
          route: AppRoutes.sikayetHaritasi);
    case HomeMenuEntry.sikayetlerim:
      return const ModuleCardSpec(
          icon: Icons.feedback_outlined,
          title: 'Şikayetlerim',
          accent: _purple,
          route: AppRoutes.sikayetlerim);
    case HomeMenuEntry.yoneticiIletisim:
      return const ModuleCardSpec(
          icon: Icons.contact_phone,
          title: 'Yönetici İletişim',
          accent: _navy,
          route: AppRoutes.yoneticiIletisim);
  }
}
