import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../announcements/data/announcement_api.dart';
import '../../announcements/domain/announcement_models.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cameras/data/cameras_api.dart';
import '../../cameras/domain/camera_models.dart';
import '../../cameras/presentation/kameralar_screen.dart' show kameraAc;
import '../../dues/data/dues_api.dart';
import '../../etkinlik/data/etkinlik_api.dart';
import '../../dues/domain/dues_models.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../profile/data/profile_api.dart';
import '../../site_kurali/data/site_kurali_api.dart';
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/activity_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/home_kart_id.dart';
import '../domain/home_varyant.dart';
import 'home_async.dart';
import 'home_refresh.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/duyuru_karti.dart';
import 'widgets/icerik_bolumu.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/kamera_seridi.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/home_states.dart';
import 'widgets/odeme_karti.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';
import '../data/izgara_tercihi.dart';
import 'izgara_koprusu.dart';

/// Sakin ana ekrani (referans: site-sakini.jpeg).
///
/// Bolum sirasi: karsilama → 4x2 hizli erisim izgarasi → Ödeme ve Aidat
/// Durumu → Son Hareketler → Duyurular → SITE KURALLARI → ETKINLIKLER.
///
/// Son iki bolum duyuru kartiyla AYNI desendedir (gorsel + baslik + ozet +
/// tarih/cip) ve 3 kayitla sinirlidir; "Tümünü Gör" tam listeye gider.
/// Etkinlikler `?aktif=true` ile gelir — bitisi gecmemis kayitlar, suzgec ve
/// siralama SUNUCUDA.
///
/// VERI: her sayac sakinin KENDI verisinden gelir (`/me/dues`, `/kargo`,
/// `/visitors`, `/complaints`, `/unit-complaints/mine` [+ `?kategori=gurultu`],
/// `/announcements` — hepsi sunucuda sakin-suzgecli); akis `/activity`'den.
/// Uydurma sayi YOKTUR: veri gelene kadar iskelet, hata halinde
/// "Yüklenemedi" + yeniden dene.
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final taban = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final now = DateTime.now();

    final hava = ref.watch(weatherProvider).value;
    final duesAsync = ref.watch(myDuesProvider);
    final kargoAsync = ref.watch(kargoListProvider);
    final ziyaretciAsync = ref.watch(visitorsListProvider);
    final duyuruAsync = ref.watch(sonDuyurularProvider);
    final daireSikayet = ref.watch(kendiDaireSikayetSayisiProvider);
    // Son Hareketler TEK uctan (/activity); sunucu sakini KENDI olaylariyla
    // sinirlar — istemci artik kargo/ziyaretci/odeme/talep birlestirmez.
    final hareketler = ref.watch(sonHareketlerProvider);
    // Sunucu suzgeci: sakine YALNIZ `aktif && sakin_gorebilir` doner.
    final kameralar = ref.watch(camerasProvider).value ?? const <Camera>[];
    // Ana ekran icerik bolumleri (3 kayit): kurallar sira ASC, etkinlikler
    // ?aktif=true + en yakin once — ikisi de sunucudan sirali gelir.
    final kurallar = ref.watch(anaEkranKurallariProvider).value ?? const [];
    final etkinlikler =
        ref.watch(yaklasanEtkinliklerProvider).value ?? const [];

    final units = duesAsync.value ?? const <MyDuesUnit>[];

    // Hizli erisim: her sayac GERCEK uctan; karsiligi olmayan kart yok
    // (sakin izgarasindaki 8 kartin hepsinin ucu var).
    final izgaraSecimi = ref.watch(izgaraKarolariProvider(UserRole.resident));
    final erisim = [
      // (P139.4) IZGARA ARTIK KULLANICININ: kaynak `taban.hizliErisim`
      // degil, kullanicinin tercihinden cozulen kume. Kopru secilen
      // girisi rolun MEVCUT kartiyla ROTA uzerinden esler ve eslesirse o
      // karti OLDUGU GIBI kullanir — bu yuzden asagidaki sayac `switch`i
      // hicbir degisiklik olmadan calismaya devam eder.
      for (final k in rolunKartlari(
          izgaraKartlari(izgaraSecimi, HomeVaryant.sakin, taban), UserRole.resident))
        switch (k.id) {
          HomeKartId.ziyaretciler => k.sayacla(
              ziyaretciAsync.metin((l) => l10n.sayacKayit(l.length))),
          HomeKartId.kargolarim => k.sayacla(kargoAsync.metin((l) =>
              l10n.sayacBekliyor(
                  l.where((x) => x.durum == KargoDurum.bekliyor).length))),
          HomeKartId.aidatBilgileri => k.sayacla(
              duesAsync.metin((u) => _aidatTutari(u, dil)),
              yeniIkinciAltMetin: duesAsync.metin((u) => _borcEtiketi(u, l10n)),
            ),
          HomeKartId.sikayetlerim =>
            k.sayacla(daireSikayet.metin(l10n.sayacAcik)),
          HomeKartId.duyurular => k.sayacla(
              duyuruAsync.metin((l) => l10n.sayacYeni(_yeniDuyuru(l, now)))),
          _ => k,
        },
    ];

    // Daire/blok bilgisi GERCEK /me/dues'ten; gelmeden alt satir cizilmez.
    final altBaslik = units.isEmpty
        ? ''
        : l10n.anaDaireAltBaslik(
            units.map((u) => u.no).join(', '),
            rolAdi(l10n, UserRole.resident),
          );

    return HomeCanliVeri(
      varyant: HomeVaryant.sakin,
      child: HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context,
          girisler: sakinBildirGirisleri(l10n),
          onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        onYenile: () => homeVerisiniYenile(ref, HomeVaryant.sakin),
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
                final ozet = odemeOzeti(u, dil);
                if (ozet == null) {
                  return HomeBolumHatasi(
                    baslik: l10n.bolumOdemeAidat,
                    mesaj: l10n.anaAidatKaydiYok,
                    onYenile: () => ref.invalidate(myDuesProvider),
                  );
                }
                return OdemeKarti(
                  ozet: ozet,
                  onGecmis: () => context.push(AppRoutes.myDues),
                  onSeeAll: () => context.push(AppRoutes.myDues),
                );
              },
              yukleniyor: () =>
                  HomeBolumIskeleti(baslik: l10n.bolumOdemeAidat, satir: 2),
              hata: () => HomeBolumHatasi(
                baslik: l10n.bolumOdemeAidat,
                onYenile: () => ref.invalidate(myDuesProvider),
              ),
            ),
          ),
          HomeSectionPad(
            child: hareketler.durum(
              veri: (satirlar) =>
                  SonHareketlerKarti(satirlar: hareketSatirlari(l10n, dil, satirlar, now)),
              yukleniyor: () =>
                  HomeBolumIskeleti(baslik: l10n.bolumSonHareketler),
              hata: () => HomeBolumHatasi(
                baslik: l10n.bolumSonHareketler,
                onYenile: () => ref.invalidate(sonHareketlerProvider),
              ),
            ),
          ),
          HomeSectionPad(
            child: duyuruAsync.durum(
              // Duyuru YOKSA bolum cizilmez (bos kart yerine bosluk).
              veri: (liste) => liste.isEmpty
                  ? const SizedBox.shrink()
                  : DuyuruKarti(
                      duyuru: duyuruOzeti(liste.first, now, dil),
                      onTumu: () => context.push(AppRoutes.announcements),
                    ),
              yukleniyor: () =>
                  HomeBolumIskeleti(baslik: l10n.bolumDuyurular, satir: 1),
              hata: () => HomeBolumHatasi(
                baslik: l10n.bolumDuyurular,
                onYenile: () => ref.invalidate(sonDuyurularProvider),
              ),
            ),
          ),
          // Site Kurallari — gorselli kural kartlari; dokunma kural listesine
          // (blog-tarzi tam icerik + gorsel) gider.
          HomeSectionPad(
            child: IcerikBolumu(
              baslik: l10n.bolumSiteKurallari,
              satirlar: kuralOzetleri(kurallar),
              onTumu: () => context.push(AppRoutes.siteKurallari),
              onSec: (_) => context.push(AppRoutes.siteKurallari),
            ),
          ),
          // Etkinlikler — YAKLASAN/SUREN (sunucu suzer); dokunma etkinligin
          // detayini (gorsel + zaman + aciklama + katilim) acar.
          HomeSectionPad(
            child: IcerikBolumu(
              baslik: l10n.bolumEtkinlikler,
              satirlar: etkinlikOzetleri(l10n, dil, etkinlikler),
              onTumu: () => context.push(AppRoutes.etkinlik),
              onSec: (o) => context.push(
                '${AppRoutes.etkinlik}?etkinlik_id=${o.id}',
              ),
            ),
          ),
          // CANLI KAMERA (P25c) — sakin YALNIZ `aktif && sakin_gorebilir`
          // kameralari alir (KVKK: gorunurlugu sunucu belirler, istemci ek
          // suzgec uygulamaz). Liste bossa bolum hic cizilmez.
          if (kameralar.isNotEmpty)
            KameraSeridi(
              kameralar: kameralar,
              onSeeAll: () => context.push(AppRoutes.kameralar),
              onAc: (kamera) => kameraAc(context, kamera),
            ),
        ],
      ),
      ),
    );
  }

  /// Kart sayaci: borc varsa BORC, yoksa son tahakkuk tutari.
  String _aidatTutari(List<MyDuesUnit> units, String dil) {
    if (units.isEmpty) return '—';
    final borc = _borc(units);
    // PARA: dil ne olursa olsun ₺ + Turkce gruplama (bkz. core/i18n/l10n.dart)
    // ve RTL'de ters donmesin diye LTR izolasyonlu.
    if (borc > 0) return tlIsaretli(borc, dil);
    return tlIsaretli(units.first.tahakkukKurus, dil);
  }

  String _borcEtiketi(List<MyDuesUnit> units, AppLocalizations l10n) =>
      units.isEmpty
          ? '—'
          : (_borc(units) > 0 ? l10n.anaBorcVar : l10n.anaBorcYok);

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
      ..showSnackBar(
          SnackBar(content: Text(context.l10n.ortakBolumYakinda)));
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1:
        // (P147) ARTIK ACIK. Once burada "yakında" yaziyordu ve sebebi
        // arayuz degil BACKEND'di: /notifications sakine 403 veriyordu.
        // Uc kapsam ayrimiyla acildi (sakin yalnizca KENDI satirlarini
        // gorur), sekme de gercek ekrana baglandi.
        context.push(AppRoutes.notifications);
      case 3:
        // (P154 / Asama 7.2) Sakin ZATEN buraya geliyordu; degisen sey
        // ETIKET: yuva "Raporlar" diyordu, acilan ekran Seffaflik'ti.
        // Tiklanan sey ile gorulen sey ayni adi tasimali.
        context.push(AppRoutes.transparency);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}

/// (P147) SAKININ "Bildir" GIRISLERI — ayri fonksiyon ki KILITLENEBILSIN.
///
/// TALEP/ARIZA ve SIKAYET AYRI AKISLARDIR (P22 d+e). Eskiden sakinin tek
/// "bildir" girisi Talep/Ariza idi; komsudan sikayetci olan sakin de oraya
/// giriyor, yani YANLIS KANALA yaziyordu (talep yonetime is emri olarak
/// akar, sikayet ise ANONIM ve DAIRE hedeflidir). Iki giris ayrildi:
///   * Talep/Ariza    -> /complaints        (takip: Bildirimler + liste)
///   * Komsu sikayeti -> /sikayet-haritasi  (takip: Sikayetlerim)
///
/// NEDEN DISARI ALINDI: sakinin talep/ariza KANALI daha once izgaradaki
/// karodan olculuyordu; karo P147'de kalkinca olcum noktasi buraya tasindi.
/// Kanal kapanirsa `home_menu_test` duser — sessiz bir yetki kaybi olmaz.
List<BildirGiris> sakinBildirGirisleri(AppLocalizations l10n) => [
      BildirGiris(
          icon: Icons.build_outlined,
          label: l10n.fabTalepArizaBildir,
          route: '${AppRoutes.complaints}?bildir=1'),
      BildirGiris(
          icon: Icons.campaign_outlined,
          label: l10n.fabSikayetBildir,
          route: AppRoutes.sikayetHaritasi),
      BildirGiris(
          icon: Icons.event_available_outlined,
          label: l10n.fabRezervasyonYap,
          route: AppRoutes.rezervasyon),
    ];
