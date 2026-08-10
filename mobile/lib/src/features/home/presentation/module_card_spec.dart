import 'package:flutter/material.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../../routing/app_router.dart';
import '../domain/home_menu.dart';

// (P139.4) `moduleBaslik` DOMAIN'e tasindi (`home_menu.dart`): saf bir
// giris->l10n eslemesidir ve gorunum modeli (`HizliErisimKart.baslik`)
// onu cagirmak zorunda. Buradan re-export edilir; cagri yerleri degismedi.
export '../domain/home_menu.dart' show moduleBaslik;

/// Menu girisinin ana-ekran kart sunumu: ikon + baslik + kategori vurgu rengi
/// + gidilecek rota. TEK KAYNAK — tum rol ekranlari (R1/R2/R3) bunu kullanir;
/// ikon/baslik/rota eskiden home_screen._tileData'daydi, buraya tasindi.
class ModuleCardSpec {
  const ModuleCardSpec({
    required this.icon,
    required this.accent,
    required this.route,
  });

  final IconData icon;
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
    case HomeMenuEntry.patrolPlans:
      return const ModuleCardSpec(
          icon: Icons.route_outlined,
          accent: _navy,
          route: AppRoutes.patrolPlans);
    case HomeMenuEntry.checkpoints:
      return const ModuleCardSpec(
          icon: Icons.add_location_alt_outlined,
          accent: _navy,
          route: AppRoutes.checkpoints);
    case HomeMenuEntry.aracGecis:
      return const ModuleCardSpec(
          icon: Icons.directions_car_outlined,
          accent: _navy,
          route: AppRoutes.aracGecis);
    case HomeMenuEntry.ihlaller:
      return const ModuleCardSpec(
          icon: Icons.report_gmailerrorred_outlined,
          accent: _amber,
          route: AppRoutes.ihlaller);
    case HomeMenuEntry.otopark:
      return const ModuleCardSpec(
          icon: Icons.local_parking_outlined,
          accent: _purple,
          route: AppRoutes.otopark);
    case HomeMenuEntry.vardiyalar:
      return const ModuleCardSpec(
          icon: Icons.schedule_outlined,
          accent: _navy,
          route: AppRoutes.vardiyalar);
    case HomeMenuEntry.anketler:
      return const ModuleCardSpec(
          icon: Icons.how_to_vote_outlined,
          accent: _purple,
          route: AppRoutes.anketler);
    case HomeMenuEntry.announcements:
      return const ModuleCardSpec(
          icon: Icons.campaign_outlined,
          accent: _amber,
          route: AppRoutes.announcements);
    case HomeMenuEntry.patrol:
      return const ModuleCardSpec(
          icon: Icons.directions_walk,
          accent: _navy,
          route: AppRoutes.patrol);
    case HomeMenuEntry.patrolTracking:
      return const ModuleCardSpec(
          icon: Icons.route_outlined,
          accent: _navy,
          route: AppRoutes.patrolTracking);
    case HomeMenuEntry.tasks:
      return const ModuleCardSpec(
          icon: Icons.task_alt,
          accent: _green,
          route: AppRoutes.tasks);
    case HomeMenuEntry.taskTracking:
      return const ModuleCardSpec(
          icon: Icons.fact_check_outlined,
          accent: _green,
          route: '${AppRoutes.tasks}?gorunum=yonetim');
    case HomeMenuEntry.assets:
      return const ModuleCardSpec(
          icon: Icons.inventory_2_outlined,
          accent: _green,
          route: AppRoutes.assets);
    case HomeMenuEntry.nfc:
      return const ModuleCardSpec(
          icon: Icons.nfc,
          accent: _navy,
          route: AppRoutes.nfc);
    case HomeMenuEntry.outbox:
      return const ModuleCardSpec(
          icon: Icons.outbox_outlined,
          accent: _navy,
          route: AppRoutes.outbox);
    case HomeMenuEntry.reports:
      return const ModuleCardSpec(
          icon: Icons.insights_outlined,
          accent: _teal,
          route: AppRoutes.reports);
    case HomeMenuEntry.budget:
      return const ModuleCardSpec(
          icon: Icons.savings_outlined,
          accent: _teal,
          route: AppRoutes.budget);
    case HomeMenuEntry.financialSummary:
      return const ModuleCardSpec(
          icon: Icons.query_stats_outlined,
          accent: _teal,
          route: AppRoutes.financialSummary);
    case HomeMenuEntry.transparency:
      return const ModuleCardSpec(
          icon: Icons.insights_outlined,
          accent: _teal,
          route: AppRoutes.transparency);
    case HomeMenuEntry.siteBudget:
      return const ModuleCardSpec(
          icon: Icons.pie_chart_outline,
          accent: _teal,
          route: AppRoutes.siteBudget);
    case HomeMenuEntry.myDues:
      return const ModuleCardSpec(
          icon: Icons.account_balance_wallet_outlined,
          accent: _teal,
          route: AppRoutes.myDues);
    case HomeMenuEntry.complaints:
      return const ModuleCardSpec(
          icon: Icons.rate_review_outlined,
          accent: _purple,
          route: AppRoutes.complaints);
    case HomeMenuEntry.visitors:
      return const ModuleCardSpec(
          icon: Icons.emoji_people_outlined,
          accent: _navy,
          route: AppRoutes.visitors);
    case HomeMenuEntry.kargo:
      return const ModuleCardSpec(
          icon: Icons.local_shipping_outlined,
          accent: _green,
          route: AppRoutes.kargo);
    case HomeMenuEntry.unitAccess:
      return const ModuleCardSpec(
          icon: Icons.key_outlined,
          accent: _navy,
          route: AppRoutes.unitAccess);
    case HomeMenuEntry.rezervasyon:
      return const ModuleCardSpec(
          icon: Icons.event_available_outlined,
          accent: _navy,
          route: AppRoutes.rezervasyon);
    case HomeMenuEntry.etkinlik:
      return const ModuleCardSpec(
          icon: Icons.celebration_outlined,
          accent: _amber,
          route: AppRoutes.etkinlik);
    case HomeMenuEntry.siteKurallari:
      return const ModuleCardSpec(
          icon: Icons.gavel_outlined,
          accent: _amber,
          route: AppRoutes.siteKurallari);
    case HomeMenuEntry.disHizmet:
      return const ModuleCardSpec(
          icon: Icons.handyman_outlined,
          accent: _amber,
          route: AppRoutes.disHizmet);
    case HomeMenuEntry.integrations:
      return const ModuleCardSpec(
          icon: Icons.hub_outlined,
          accent: _navy,
          route: AppRoutes.integrations);
    case HomeMenuEntry.personel:
      return const ModuleCardSpec(
          icon: Icons.badge_outlined,
          accent: _navy,
          route: AppRoutes.personel);
    case HomeMenuEntry.sakinler:
      return const ModuleCardSpec(
          icon: Icons.people_alt_outlined,
          accent: _navy,
          route: AppRoutes.sakinler);
    case HomeMenuEntry.binaDuzenleme:
      return const ModuleCardSpec(
          icon: Icons.apartment_outlined,
          accent: _navy,
          route: AppRoutes.binaDuzenleme);
    case HomeMenuEntry.daireTanimlari:
      return const ModuleCardSpec(
          icon: Icons.category_outlined,
          accent: _navy,
          route: AppRoutes.daireTanimlari);
    case HomeMenuEntry.sikayetHaritasi:
      return const ModuleCardSpec(
          icon: Icons.grid_view_outlined,
          accent: _purple,
          route: AppRoutes.sikayetHaritasi);
    case HomeMenuEntry.sikayetlerim:
      return const ModuleCardSpec(
          icon: Icons.feedback_outlined,
          accent: _purple,
          route: AppRoutes.sikayetlerim);
    case HomeMenuEntry.yoneticiIletisim:
      return const ModuleCardSpec(
          icon: Icons.contact_phone,
          accent: _navy,
          route: AppRoutes.yoneticiIletisim);
  }
}


