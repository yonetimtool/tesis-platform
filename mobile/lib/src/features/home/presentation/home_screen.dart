import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scan/data/scan_outbox.dart';
import '../domain/home_menu.dart';

/// Giris sonrasi ana ekran — menu, role gore bilesir (home_menu.dart;
/// contracts/auth.md §4 UX aynasi). Rol cozulene kadar (storage okumasi,
/// saniye alti) yalnizca baslik gorunur.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxState = ref.watch(scanOutboxProvider);
    final role =
        ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final entries = homeMenuForRole(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana ekran'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      // Cok kartli rolde (or. guvenlik) icerik kucuk ekrani asabildiginden
      // liste kaydirilabilir; icerik sigarsa eski gorunum gibi ortali kalir.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // 48 = dikey padding (24 ust + 24 alt); negatife dusmesin.
                minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity).toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Giriş başarılı',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (role != UserRole.unknown)
                      Text(
                        role.label,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    const SizedBox(height: 24),
                    for (final entry in entries)
                      _menuCard(context, entry, outboxState),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    HomeMenuEntry entry,
    ScanOutboxState outboxState,
  ) {
    switch (entry) {
      case HomeMenuEntry.emergency:
        // Belirgin (kirmizi) giris; yanlis basmaya karsi asil koruma
        // ekrandaki ONAY dialogudur.
        return Card(
          color: Colors.red,
          child: ListTile(
            leading: const Icon(Icons.sos, color: Colors.white, size: 32),
            title: const Text(
              'ACİL DURUM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Panik butonu — yönetime alarm gönder',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white),
            onTap: () => context.push(AppRoutes.emergency),
          ),
        );
      case HomeMenuEntry.announcements:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Duyurular'),
            subtitle: const Text('Yönetimden tesise duyurular'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.announcements),
          ),
        );
      case HomeMenuEntry.patrol:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.directions_walk),
            title: const Text('Turlarım'),
            subtitle: const Text(
              'Aktif devriye penceresi ve nokta ilerlemesi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.patrol),
          ),
        );
      case HomeMenuEntry.patrolTracking:
        // Yonetici: salt izleme — panelin canli ozetinin mobil karsiligi.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Devriye takibi'),
            subtitle: const Text(
              'Bugünün turları, nokta ilerlemesi ve geçmiş',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.patrolTracking),
          ),
        );
      case HomeMenuEntry.tasks:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Görevlerim'),
            subtitle: const Text(
              'Görev listesi ve foto kanıtlı tamamlama',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.tasks),
          ),
        );
      case HomeMenuEntry.taskTracking:
        // Gorev-YONETIMI: tum gorev/atama takibi ("Herkes" kapsamiyla
        // acilir). "Yeni gorev" butonu ekranda rol kapilidir (yonetim).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Görev yönetimi'),
            subtitle: const Text(
              'Tüm görevleri ve atamaları izle; atama yönetimde',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('${AppRoutes.tasks}?gorunum=yonetim'),
          ),
        );
      case HomeMenuEntry.assets:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Demirbaş'),
            subtitle: const Text(
              'NFC ile zimmet al/bırak, üzerimdekiler',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.assets),
          ),
        );
      case HomeMenuEntry.nfc:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.nfc),
            title: const Text('NFC etiket okuma'),
            subtitle: const Text('Devriye noktası etiketini okut'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.nfc),
          ),
        );
      case HomeMenuEntry.outbox:
        return Card(
          child: ListTile(
            leading: Badge(
              isLabelVisible: outboxState.pendingCount > 0,
              label: Text('${outboxState.pendingCount}'),
              child: const Icon(Icons.outbox_outlined),
            ),
            title: const Text('Gönderim kuyruğu'),
            subtitle: Text(
              outboxState.pendingCount > 0
                  ? '${outboxState.pendingCount} okutma gönderim bekliyor'
                  : outboxState.failedCount > 0
                      ? '${outboxState.failedCount} kalıcı hata var'
                      : 'Bekleyen okutma yok',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.outbox),
          ),
        );
      case HomeMenuEntry.reports:
        // Yonetici: ay bazli devriye/gorev/aidat ozeti (salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Aylık raporlar'),
            subtitle: const Text(
              'Devriye, görev tamamlama ve aidat özeti',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.reports),
          ),
        );
      case HomeMenuEntry.budget:
        // Yonetici: butce — kategoriler, gelir/gider defteri, kasa ozeti.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Bütçe'),
            subtitle: const Text(
              'Gelir/gider defteri, kategoriler ve kasa özeti',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.budget),
          ),
        );
      case HomeMenuEntry.financialSummary:
        // Yonetici: cepten gunluk/donemsel finansal rapor (salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.query_stats_outlined),
            title: const Text('Finansal özet'),
            subtitle: const Text(
              'Tahsilat oranı, gelir/gider/kasa ve en yüksek giderler',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.financialSummary),
          ),
        );
      case HomeMenuEntry.siteBudget:
        // Resident: site butcesinin agregat ozeti (seffaflik; salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Site Bütçesi'),
            subtitle: const Text(
              'Sitenin toplam gelir, gider ve kasa özeti (şeffaflık)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.siteBudget),
          ),
        );
      case HomeMenuEntry.myDues:
        // Resident: kendi dairelerinin borc durumu (salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Aidatım'),
            subtitle: const Text(
              'Daire borç durumu, tahakkuk ve ödeme geçmişi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.myDues),
          ),
        );
      case HomeMenuEntry.complaints:
        // Sakin<->yonetim kanali: sakin talep acar, yonetim yanitlar.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('Şikayet / Öneri'),
            subtitle: const Text(
              'Yönetime talep ilet, durum ve yanıtı izle',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.complaints),
          ),
        );
      case HomeMenuEntry.visitors:
        // Kapi onay akisi: guvenlik kaydeder, dairenin sakini onaylar/reddeder.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.emoji_people_outlined),
            title: const Text('Ziyaretçiler'),
            subtitle: const Text(
              'Kapıdaki ziyaretçi kaydı, onay/red ve geçmiş',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.visitors),
          ),
        );
      case HomeMenuEntry.kargo:
        // Paket takibi: guvenlik kaydeder (foto ile), sakin teslim alir.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Kargo'),
            subtitle: const Text(
              'Gelen paket kaydı, teslim durumu ve geçmiş',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.kargo),
          ),
        );
      case HomeMenuEntry.unitAccess:
        // Tek-seferlik daire goruntuleme izni (KVKK): admin/yonetici talep
        // acar + onaylananlari bir kez gorur; resident gelenleri onaylar.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Görüntüleme izni'),
            subtitle: const Text(
              'Daire ziyaretçi/kargo kayıtları için tek seferlik erişim',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.unitAccess),
          ),
        );
      case HomeMenuEntry.rezervasyon:
        // Ortak alan rezervasyonu: sakin slot ister, yonetim onaylar.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Rezervasyon'),
            subtitle: const Text(
              'Ortak alan (havuz, toplantı odası) slot talebi ve onay',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.rezervasyon),
          ),
        );
      case HomeMenuEntry.etkinlik:
        // Etkinlik + RSVP: yonetim duyurur, sakin katilim beyan eder;
        // sayilar herkese seffaf.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: const Text('Etkinlikler'),
            subtitle: const Text(
              'Site etkinlikleri; katılım beyanı ve şeffaf sayılar',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.etkinlik),
          ),
        );
      case HomeMenuEntry.siteKurallari:
        // Blog-tarzi kural listesi: yonetim yazar, herkes okur; baslik arama.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Site Kuralları'),
            subtitle: const Text(
              'Site yaşam kuralları; başlıkta arama',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.siteKurallari),
          ),
        );
      case HomeMenuEntry.integrations:
        // C1b: dis sistem entegrasyonlari (megafon/akilli-ev/webhook) — konfig
        // + SSRF-korumali tetik. Yonetici yonetir.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Entegrasyonlar'),
            subtitle: const Text(
              'Dış sistemler (megafon/akıllı ev/webhook) — kur, tetikle',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.integrations),
          ),
        );
      case HomeMenuEntry.binaYerlesimi:
        // D-viz-1: daire yerlesimi (blok/kat/sira) girisi + anonim yogunluk
        // onizlemesi. Yonetici yonetir; cizim (2D sema) sonraki tur.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Bina Yerleşimi'),
            subtitle: const Text(
              'Daire blok/kat/sıra girişi — şikayet yoğunluğu haritası',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.binaYerlesimi),
          ),
        );
      case HomeMenuEntry.binaDuzenleme:
        // D-viz Rev-2: gorsel bina editoru — blok/kat/daire olustur/duzenle.
        // Yonetici kurar; Sikayet Haritasi bu yapiyi yansitir.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.edit_location_alt_outlined),
            title: const Text('Bina Düzenleme'),
            subtitle: const Text(
              'Blok, kat ve daireleri görsel olarak oluştur/düzenle',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.binaDuzenleme),
          ),
        );
      case HomeMenuEntry.sikayetHaritasi:
        // D-viz-2: 2D bina semasi (kat plani) — renkli daire hucreleri.
        // Tum roller gorur; sakin daireyi anonim sikayet edebilir.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: const Text('Şikayet Haritası'),
            subtitle: const Text(
              'Bina şeması — daire yoğunluğu (yeşil/sarı/kırmızı)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sikayetHaritasi),
          ),
        );
      case HomeMenuEntry.sikayetlerim:
        // Rev-1.1: sakin kendi actigi sikayetleri + durum gorur.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Şikayetlerim'),
            subtitle: const Text('Açtığınız daire şikayetleri ve durumları'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sikayetlerim),
          ),
        );
    }
  }
}
