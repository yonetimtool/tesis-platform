import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../../core/text/tr_upper.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scan/data/scan_outbox.dart';
import '../../tenant/data/tenant_api.dart';
import '../domain/home_menu.dart';

/// Giris sonrasi ana ekran — menu, role gore bilesir (home_menu.dart;
/// contracts/auth.md §4 UX aynasi). Rol cozulene kadar (storage okumasi,
/// saniye alti) yalnizca baslik gorunur.
///
/// Gorunum: ACIL DURUM (varsa) ustte tam-genislik banner; kalan menuler
/// 2 sutunlu kompakt ikon-izgara (buyuk ikon + BUYUK HARF baslik).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxState = ref.watch(scanOutboxProvider);
    final role =
        ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final entries = homeMenuForRole(role);

    final hasEmergency = entries.contains(HomeMenuEntry.emergency);
    final gridEntries =
        entries.where((e) => e != HomeMenuEntry.emergency).toList();

    // Sol ustte tesis (site) adi — herkes kendi sitesini gorur. Kurulum
    // tamamlanana / yuklenene kadar notr baslik.
    final siteAd = ref.watch(tenantSettingsProvider).value?.ad;
    final baslik = (siteAd != null && siteAd.trim().isNotEmpty)
        ? siteAd
        : 'Ana ekran';

    return Scaffold(
      appBar: AppBar(
        // Yönetio marka isareti sol ustte (yalniz ana ekran app-bar'i); site
        // adi baslik olarak kalir.
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: YonetioLogoMark(size: 30)),
        ),
        leadingWidth: 54,
        title: Text(baslik),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (role != UserRole.unknown) ...[
                Text(
                  role.label,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (hasEmergency) ...[
                _emergencyBanner(context),
                const SizedBox(height: 16),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  for (final entry in gridEntries)
                    _gridTile(context, entry, outboxState),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Belirgin (kirmizi) ACIL DURUM girisi — tam genislik; yanlis basmaya
  /// karsi asil koruma ekrandaki ONAY dialogudur.
  Widget _emergencyBanner(BuildContext context) {
    return Card(
      color: Colors.red,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.emergency),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.sos, color: Colors.white, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACİL DURUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Panik butonu — yönetime alarm gönder',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  /// Kompakt izgara kutucugu: ortada buyuk ikon + BUYUK HARF baslik.
  /// Gonderim kuyrugu kutucugu bekleyen sayiyi ikon uzerinde rozetler.
  Widget _gridTile(
    BuildContext context,
    HomeMenuEntry entry,
    ScanOutboxState outboxState,
  ) {
    final data = _tileData(context, entry, outboxState);
    final iconColor = Theme.of(context).colorScheme.primary;
    Widget icon = Icon(data.icon, size: 34, color: iconColor);
    if (data.badge != null && data.badge! > 0) {
      icon = Badge(label: Text('${data.badge}'), child: icon);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 12),
              Text(
                trUpper(data.title),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menu girisi -> kutucuk verisi (ikon, baslik, dokunma, opsiyonel rozet).
  /// Rota ve rol-kapisi mantigi degismedi; yalniz gorunum sadelesti.
  ({IconData icon, String title, VoidCallback onTap, int? badge}) _tileData(
    BuildContext context,
    HomeMenuEntry entry,
    ScanOutboxState outboxState,
  ) {
    switch (entry) {
      case HomeMenuEntry.emergency:
        // Banner olarak cizilir; butunluk (exhaustive switch) icin burada da var.
        return (
          icon: Icons.sos,
          title: 'ACİL DURUM',
          onTap: () => context.push(AppRoutes.emergency),
          badge: null,
        );
      case HomeMenuEntry.announcements:
        return (
          icon: Icons.campaign_outlined,
          title: 'Duyurular',
          onTap: () => context.push(AppRoutes.announcements),
          badge: null,
        );
      case HomeMenuEntry.patrol:
        return (
          icon: Icons.directions_walk,
          title: 'Turlarım',
          onTap: () => context.push(AppRoutes.patrol),
          badge: null,
        );
      case HomeMenuEntry.patrolTracking:
        // Yonetici: salt izleme — panelin canli ozetinin mobil karsiligi.
        return (
          icon: Icons.route_outlined,
          title: 'Devriye takibi',
          onTap: () => context.push(AppRoutes.patrolTracking),
          badge: null,
        );
      case HomeMenuEntry.tasks:
        return (
          icon: Icons.task_alt,
          title: 'Görevlerim',
          onTap: () => context.push(AppRoutes.tasks),
          badge: null,
        );
      case HomeMenuEntry.taskTracking:
        // Gorev-YONETIMI: tum gorev/atama takibi ("Herkes" kapsamiyla acilir).
        // "Yeni gorev" butonu ekranda rol kapilidir (yonetim).
        return (
          icon: Icons.fact_check_outlined,
          title: 'Görev yönetimi',
          onTap: () => context.push('${AppRoutes.tasks}?gorunum=yonetim'),
          badge: null,
        );
      case HomeMenuEntry.assets:
        return (
          icon: Icons.inventory_2_outlined,
          title: 'Demirbaş',
          onTap: () => context.push(AppRoutes.assets),
          badge: null,
        );
      case HomeMenuEntry.nfc:
        return (
          icon: Icons.nfc,
          title: 'NFC etiket okuma',
          onTap: () => context.push(AppRoutes.nfc),
          badge: null,
        );
      case HomeMenuEntry.outbox:
        return (
          icon: Icons.outbox_outlined,
          title: 'Gönderim kuyruğu',
          onTap: () => context.push(AppRoutes.outbox),
          badge: outboxState.pendingCount,
        );
      case HomeMenuEntry.reports:
        // Yonetici: ay bazli devriye/gorev/aidat ozeti (salt okuma).
        return (
          icon: Icons.insights_outlined,
          title: 'Aylık raporlar',
          onTap: () => context.push(AppRoutes.reports),
          badge: null,
        );
      case HomeMenuEntry.budget:
        // Yonetici: butce — kategoriler, gelir/gider defteri, kasa ozeti.
        return (
          icon: Icons.savings_outlined,
          title: 'Bütçe',
          onTap: () => context.push(AppRoutes.budget),
          badge: null,
        );
      case HomeMenuEntry.financialSummary:
        // Yonetici: cepten gunluk/donemsel finansal rapor (salt okuma).
        return (
          icon: Icons.query_stats_outlined,
          title: 'Finansal özet',
          onTap: () => context.push(AppRoutes.financialSummary),
          badge: null,
        );
      case HomeMenuEntry.siteBudget:
        // Resident: site butcesinin agregat ozeti (seffaflik; salt okuma).
        return (
          icon: Icons.pie_chart_outline,
          title: 'Site Bütçesi',
          onTap: () => context.push(AppRoutes.siteBudget),
          badge: null,
        );
      case HomeMenuEntry.myDues:
        // Resident: kendi dairelerinin borc durumu (salt okuma).
        return (
          icon: Icons.account_balance_wallet_outlined,
          title: 'Aidatım',
          onTap: () => context.push(AppRoutes.myDues),
          badge: null,
        );
      case HomeMenuEntry.complaints:
        // Sakin<->yonetim kanali: sakin talep acar, yonetim yanitlar.
        return (
          icon: Icons.rate_review_outlined,
          title: 'Şikayet / Öneri',
          onTap: () => context.push(AppRoutes.complaints),
          badge: null,
        );
      case HomeMenuEntry.visitors:
        // Kapi onay akisi: guvenlik kaydeder, dairenin sakini onaylar/reddeder.
        return (
          icon: Icons.emoji_people_outlined,
          title: 'Ziyaretçiler',
          onTap: () => context.push(AppRoutes.visitors),
          badge: null,
        );
      case HomeMenuEntry.kargo:
        // Paket takibi: guvenlik kaydeder (foto ile), sakin teslim alir.
        return (
          icon: Icons.local_shipping_outlined,
          title: 'Kargo',
          onTap: () => context.push(AppRoutes.kargo),
          badge: null,
        );
      case HomeMenuEntry.unitAccess:
        // Tek-seferlik daire goruntuleme izni (KVKK): admin/yonetici talep
        // acar + onaylananlari bir kez gorur; resident gelenleri onaylar.
        return (
          icon: Icons.key_outlined,
          title: 'Görüntüleme izni',
          onTap: () => context.push(AppRoutes.unitAccess),
          badge: null,
        );
      case HomeMenuEntry.rezervasyon:
        // Ortak alan rezervasyonu: sakin slot ister, yonetim onaylar.
        return (
          icon: Icons.event_available_outlined,
          title: 'Rezervasyon',
          onTap: () => context.push(AppRoutes.rezervasyon),
          badge: null,
        );
      case HomeMenuEntry.etkinlik:
        // Etkinlik + RSVP: yonetim duyurur, sakin katilim beyan eder;
        // sayilar herkese seffaf.
        return (
          icon: Icons.celebration_outlined,
          title: 'Etkinlikler',
          onTap: () => context.push(AppRoutes.etkinlik),
          badge: null,
        );
      case HomeMenuEntry.siteKurallari:
        // Blog-tarzi kural listesi: yonetim yazar, herkes okur; baslik arama.
        return (
          icon: Icons.gavel_outlined,
          title: 'Site Kuralları',
          onTap: () => context.push(AppRoutes.siteKurallari),
          badge: null,
        );
      case HomeMenuEntry.disHizmet:
        // Guvenilir esnaf/hizmet kisileri + yonetici notu; yonetim yazar, okur.
        return (
          icon: Icons.handyman_outlined,
          title: 'Dış Hizmetler',
          onTap: () => context.push(AppRoutes.disHizmet),
          badge: null,
        );
      case HomeMenuEntry.integrations:
        // C1b: dis sistem entegrasyonlari (megafon/akilli-ev/webhook) — konfig
        // + SSRF-korumali tetik. Yonetici yonetir.
        return (
          icon: Icons.hub_outlined,
          title: 'Entegrasyonlar',
          onTap: () => context.push(AppRoutes.integrations),
          badge: null,
        );
      case HomeMenuEntry.personel:
        // Ozellik 3: yonetici/admin saha personeli (guvenlik/tesis gorevlisi)
        // listeler + ekler. yonetici YALNIZ saha personeli acar (backend RBAC).
        return (
          icon: Icons.badge_outlined,
          title: 'Saha Personeli',
          onTap: () => context.push(AppRoutes.personel),
          badge: null,
        );
      case HomeMenuEntry.sakinler:
        // Site sakini yonetimi: yonetici/admin sakinleri listeler, ekler
        // (daire + gecici kod), cikarir (pasiflestir). Sakin kendi kayit olamaz.
        return (
          icon: Icons.people_alt_outlined,
          title: 'Site Sakinleri',
          onTap: () => context.push(AppRoutes.sakinler),
          badge: null,
        );
      case HomeMenuEntry.binaDuzenleme:
        // D-viz Rev-2: gorsel bina yapisi — blok/kat/daire. Yonetim (admin/
        // yonetici) olusturur/duzenler; security + tesis_gorevlisi SALT-OKUMA
        // gorur (duzenleme yok). Ekran role gore kilitlenir.
        return (
          icon: Icons.apartment_outlined,
          title: 'Bina Yapısı',
          onTap: () => context.push(AppRoutes.binaDuzenleme),
          badge: null,
        );
      case HomeMenuEntry.sikayetHaritasi:
        // D-viz-2: 2D bina semasi (kat plani) — renkli daire hucreleri.
        // Tum roller gorur; sakin daireyi anonim sikayet edebilir.
        return (
          icon: Icons.grid_view_outlined,
          title: 'Şikayet Haritası',
          onTap: () => context.push(AppRoutes.sikayetHaritasi),
          badge: null,
        );
      case HomeMenuEntry.sikayetlerim:
        // Rev-1.1: sakin kendi actigi sikayetleri + durum gorur.
        return (
          icon: Icons.feedback_outlined,
          title: 'Şikayetlerim',
          onTap: () => context.push(AppRoutes.sikayetlerim),
          badge: null,
        );
    }
  }
}
