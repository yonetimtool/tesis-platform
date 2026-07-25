import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../announcements/data/announcement_api.dart';
import '../../announcements/domain/announcement_models.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../complaints/data/complaint_api.dart';
import '../../dues/data/dues_api.dart';
import '../../dues/domain/dues_models.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../profile/data/profile_api.dart';
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import 'home_async.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/duyuru_karti.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/home_states.dart';
import 'widgets/odeme_karti.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';

/// Sakin ana ekrani (referans: site-sakini.jpeg).
///
/// Bolum sirasi gorselle birebir: karsilama → 4x2 hizli erisim izgarasi →
/// Ödeme ve Aidat Durumu → Son Hareketler → Duyurular.
///
/// VERI: her sayac sakinin KENDI verisinden gelir (`/me/dues`, `/kargo`,
/// `/visitors`, `/complaints`, `/unit-complaints/mine`, `/announcements` —
/// hepsi sunucuda sakin-suzgecli). Uydurma sayi YOKTUR: veri gelene kadar
/// iskelet, hata halinde "Yüklenemedi" + yeniden dene.
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taban = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final now = DateTime.now();

    final hava = ref.watch(weatherProvider).value;
    final duesAsync = ref.watch(myDuesProvider);
    final kargoAsync = ref.watch(kargoListProvider);
    final ziyaretciAsync = ref.watch(visitorsListProvider);
    final duyuruAsync = ref.watch(sonDuyurularProvider);
    final talep = ref.watch(acikSikayetSayisiProvider);
    final daireSikayet = ref.watch(kendiDaireSikayetSayisiProvider);
    final hareketler = ref.watch(residentHareketleriProvider);

    final units = duesAsync.value ?? const <MyDuesUnit>[];

    // Hizli erisim: her sayac GERCEK uctan; karsiligi olmayan kart yok
    // (sakin izgarasindaki 8 kartin hepsinin ucu var).
    final erisim = [
      for (final k in taban.hizliErisim(HomeVaryant.sakin))
        switch (k.baslik) {
          'Ziyaretçiler' =>
            k.sayacla(ziyaretciAsync.sayac((l) => l.length, 'Kayıt')),
          'Kargolarım' => k.sayacla(kargoAsync.sayac(
              (l) => l.where((x) => x.durum == KargoDurum.bekliyor).length,
              'Bekliyor',
            )),
          'Aidat Bilgileri' => k.sayacla(
              duesAsync.metin(_aidatTutari),
              yeniIkinciAltMetin: duesAsync.metin(_borcEtiketi),
            ),
          'Geri Bildirim' => k.sayacla(talep.sayac((n) => n, 'Açık')),
          'Şikayetlerim' => k.sayacla(daireSikayet.sayac((n) => n, 'Açık')),
          'Duyurular' =>
            k.sayacla(duyuruAsync.sayac((l) => _yeniDuyuru(l, now), 'Yeni')),
          _ => k,
        },
    ];

    // Daire/blok bilgisi GERCEK /me/dues'ten; gelmeden alt satir cizilmez.
    final altBaslik = units.isEmpty
        ? ''
        : 'Daire ${units.map((u) => u.no).join(', ')}  •  '
            '${UserRole.resident.label}';

    return HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context, girisler: const [
        BildirGiris(
            icon: Icons.rate_review_outlined,
            label: 'Talep / Arıza Bildir',
            route: AppRoutes.complaints),
        BildirGiris(
            icon: Icons.event_available_outlined,
            label: 'Rezervasyon Yap',
            route: AppRoutes.rezervasyon),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        header: HomeHeader(
          greetingName: ad,
          subtitle: altBaslik,
          hava: hava == null ? null : havaOzeti(hava),
        ),
        bolumler: [
          HomeSectionPad(
            child: HizliErisimIzgarasi(
              kartlar: erisim,
              onSec: (k) => k.rota == null
                  ? _yakinda(context)
                  : context.push(k.rota!),
            ),
          ),
          HomeSectionPad(
            child: duesAsync.durum(
              veri: (u) {
                final ozet = odemeOzeti(u);
                if (ozet == null) {
                  return HomeBolumHatasi(
                    baslik: 'Ödeme ve Aidat Durumu',
                    mesaj: 'Aidat kaydı bulunamadı',
                    onYenile: () => ref.invalidate(myDuesProvider),
                  );
                }
                return OdemeKarti(
                  ozet: ozet,
                  onGecmis: () => context.push(AppRoutes.myDues),
                  onSeeAll: () => context.push(AppRoutes.myDues),
                );
              },
              yukleniyor: () => const HomeBolumIskeleti(
                  baslik: 'Ödeme ve Aidat Durumu', satir: 2),
              hata: () => HomeBolumHatasi(
                baslik: 'Ödeme ve Aidat Durumu',
                onYenile: () => ref.invalidate(myDuesProvider),
              ),
            ),
          ),
          HomeSectionPad(
            child: hareketler.durum(
              veri: (satirlar) =>
                  SonHareketlerKarti(satirlar: hareketSatirlari(satirlar, now)),
              yukleniyor: () =>
                  const HomeBolumIskeleti(baslik: 'Son Hareketler'),
              hata: () => HomeBolumHatasi(
                baslik: 'Son Hareketler',
                onYenile: () => ref.invalidate(residentHareketleriProvider),
              ),
            ),
          ),
          HomeSectionPad(
            child: duyuruAsync.durum(
              // Duyuru YOKSA bolum cizilmez (bos kart yerine bosluk).
              veri: (liste) => liste.isEmpty
                  ? const SizedBox.shrink()
                  : DuyuruKarti(
                      duyuru: duyuruOzeti(liste.first, now),
                      onTumu: () => context.push(AppRoutes.announcements),
                    ),
              yukleniyor: () =>
                  const HomeBolumIskeleti(baslik: 'Duyurular', satir: 1),
              hata: () => HomeBolumHatasi(
                baslik: 'Duyurular',
                onYenile: () => ref.invalidate(sonDuyurularProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kart sayaci: borc varsa BORC, yoksa son tahakkuk tutari.
  String _aidatTutari(List<MyDuesUnit> units) {
    if (units.isEmpty) return '—';
    final borc = _borc(units);
    if (borc > 0) return '₺${formatKurusAsTl(borc)}';
    return '₺${formatKurusAsTl(units.first.tahakkukKurus)}';
  }

  String _borcEtiketi(List<MyDuesUnit> units) =>
      units.isEmpty ? '—' : (_borc(units) > 0 ? 'Borç Var' : 'Borç Yok');

  int _borc(List<MyDuesUnit> units) => units.fold<int>(
      0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));

  /// "N Yeni" — son 3 gunde yayinlanan duyuru sayisi (duyuru kartindaki
  /// "Yeni" cipiyle AYNI esik, bkz. [duyuruOzeti]).
  int _yeniDuyuru(List<Announcement> liste, DateTime now) => liste
      .where((d) => now.difference(d.createdAt) <= const Duration(days: 3))
      .length;

  void _yakinda(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Bu bölüm yakında')));
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler — /notifications RBAC sakine kapali (backend).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Bildirimler yakında')));
      case 3: // Raporlar — sakin icin seffaflik (aylik anonim ozet).
        context.push(AppRoutes.transparency);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
