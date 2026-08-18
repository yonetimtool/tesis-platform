import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../../auth/domain/user_role.dart';
import '../../../notifications/data/notifications_controller.dart';
import '../../../profile/data/avatar_api.dart';
import '../../../push/domain/push_models.dart';
import '../../../push/presentation/push_registrar.dart';
import '../../../../routing/app_router.dart';
import '../../domain/home_tabs.dart';
import 'dil_modali.dart';
import 'home_drawer.dart';
import 'home_marka.dart';
import '../../../../core/ui/gorsel_cozme.dart';
import '../../../../core/ui/merkez_diyalog.dart';

/// Referans ana ekranin ORTAK KABUGU — uc rol varyantinda da AYNI widget:
///   * app-bar: solda hamburger, yaninda marka kilidi, sagda rozetli zil +
///     40px avatar (sag altinda yesil online noktasi),
///   * govde slotu,
///   * 5 yuvali alt-bar ([homeShellSlots]) — merkez yuva bar'in USTUNE tasan
///     56px mavi FAB.
///
/// Rota cozumu DISARIDA: [onDestinationSelected] yuva indeksini verir, merkez
/// FAB [onBildir]'i cagirir. Hamburger cekmecesi rolun tum modullerini
/// listeler ([HomeDrawer]).
class HomeShell extends ConsumerWidget {
  const HomeShell({
    super.key,
    required this.role,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onBildir,
    required this.onModul,
    this.onProfile,
    this.onLogout,
    this.unreadCount = 0,
  });

  final UserRole role;
  final Widget body;

  /// Aktif destinasyon yuva indeksi (0/1/3/4; merkez FAB=2 secilemez).
  final int currentIndex;

  /// Destinasyon dokunuldu — yuva indeksi (0,1,3,4).
  final ValueChanged<int> onDestinationSelected;

  /// Merkez "Bildir" FAB.
  final VoidCallback onBildir;

  /// Cekmeceden modul secildi — rota.
  final ValueChanged<String> onModul;

  /// Hesap menusu / cekmece "Profil".
  final VoidCallback? onProfile;

  /// "Çıkış Yap" — oturumu temizleyip login'e doner.
  final VoidCallback? onLogout;

  /// Bildirim zili rozet sayisi (0 → rozet yok).
  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = HomeSurface.of(context);

    // ON PLANDA gelen push: FCM bunu sistem tepsisine DUSURMEZ — uygulama
    // acikken kullaniciya gostermek BIZIM isimiz. Tur 45'e kadar mesaj
    // yalniz `PushState.sonBildirim` alanina yaziliyordu ve HICBIR EKRAN
    // okumuyordu: bildirim geldiginde kullanici hicbir sey gormuyordu ve
    // zil rozeti de artmiyordu (rozet ayri bir uctan geliyor, tazelenmesi
    // gerekiyor).
    ref.listen<PushMessageEvent?>(
      pushRegistrarProvider.select((p) => p.sonBildirim),
      (onceki, yeni) {
        if (yeni == null || yeni == onceki) return;
        final l10n = context.l10n;
        // Metin SUNUCUDAN gelir (cihazin diline gore uretilir, tur 16);
        // yuk bossa cizim katmani kendi cevrilmis metnini yazar.
        final metin = yeni.displayText.isEmpty
            ? l10n.bildirimYeniPush
            : yeni.displayText;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                metin,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              action: SnackBarAction(
                label: l10n.ortakGoster,
                onPressed: () => onDestinationSelected(1),
              ),
            ),
          );
        // Rozet sayaci ayri uctan gelir; push gelince TAZELENMELI.
        ref.invalidate(unreadNotificationCountProvider);
      },
    );

    return Scaffold(
      backgroundColor: s.background,
      drawer: HomeDrawer(
        role: role,
        onModul: onModul,
        onProfile: onProfile,
        onLogout: onLogout,
      ),
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: s.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: s.heading),
        titleSpacing: 0,
        title: const HomeMarka(),
        actions: [
          // (P168 §6) KISAYOL IZGARASI — referans ust barin "izgara"
          // dugmesi. Ana ekran karolarini duzenleme ekrani ZATEN VARDI
          // (`/ana-ekran-duzenle`) ama ona yalnizca menuden ulasilabiliyordu;
          // yani en cok kullanilan kisayollari duzenlemek icin once menuyu
          // acmak gerekiyordu.
          _IzgaraButonu(onTap: () => context.push(AppRoutes.izgaraDuzenle)),
          const SizedBox(width: 4),
          _ZilButonu(
            unreadCount: unreadCount,
            onTap: () => onDestinationSelected(1),
          ),
          const SizedBox(width: 4),
          // (P140.4) DIL SIMGESI PROFILIN YANINDA — sag ust.
          const DilButonu(),
          const SizedBox(width: 4),
          _AvatarButonu(onTap: () => _hesapMenusu(context)),
          const SizedBox(width: 12),
        ],
      ),
      body: body,
      bottomNavigationBar: _HomeBottomBar(
        role: role,
        currentIndex: currentIndex,
        unreadCount: unreadCount,
        onDestinationSelected: onDestinationSelected,
        onBildir: onBildir,
      ),
    );
  }

  /// Hesap menusu (referans: header avatari) — Profil + Çıkış Yap.
  void _hesapMenusu(BuildContext context) {
    merkezSayfaAc<void>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(context.l10n.kabukProfil),
              onTap: () {
                Navigator.of(ctx).pop();
                onProfile?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: HomeTokens.red),
              title: Text(
                context.l10n.kabukCikisYap,
                style: const TextStyle(color: HomeTokens.red),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onLogout?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Zil + sag ustunde kirmizi sayi rozeti.
class _ZilButonu extends StatelessWidget {
  const _ZilButonu({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return IconButton(
      tooltip: context.l10n.sekmeBildirimler,
      onPressed: onTap,
      icon: unreadCount > 0
          ? Badge(
              // (P166 §7.2) Rozet TEMAYA GORE: koyu tema acilinca sabit
              // kirmizi app bar zemininde AA'nin altina dusuyordu.
              backgroundColor: s.badge,
              label: Text('$unreadCount', style: TextStyle(color: s.badgeOn)),
              child: Icon(Icons.notifications_outlined, color: s.heading),
            )
          : Icon(Icons.notifications_outlined, color: s.heading),
    );
  }
}

/// 40px yuvarlak avatar + sag altinda yesil online noktasi.
/// (P168 §6) IZGARA/KISAYOL dugmesi — ana ekran karolarini duzenleme.
class _IzgaraButonu extends StatelessWidget {
  const _IzgaraButonu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return IconButton(
      // ADSIZ IKON DUGMESI OLMAZ: ekran okuyucu yalnizca "dugme" der.
      tooltip: context.l10n.kabukKisayollar,
      icon: Icon(Icons.grid_view_outlined, color: s.heading),
      onPressed: onTap,
    );
  }
}


class _AvatarButonu extends StatelessWidget {
  const _AvatarButonu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    // Avatar dugmesi ekran okuyucuda ADSIZDI (tur 34): yalnizca "dugme"
    // diye okunuyordu. `MergeSemantics` etiketi DOKUNULABILIR dugumle
    // birlestirir (disardan `Semantics` sarmasi ayri dugum yaratir).
    return MergeSemantics(
      child: Semantics(
        label: context.l10n.kabukProfil,
        child: InkResponse(
          key: const Key('home-avatar'),
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            // Dokunma hedefi 48 dp (tur 34): avatar 44x44 idi. Gorsel cap
            // (CircleAvatar radius 20) DEGISMEZ, yalniz dokunma kutusu buyur.
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    // Personel avatari varsa resimli goster; yoksa/hata varsa ikon
                    // fallback (ekran dusmez). Resident'ta uc 403 -> null -> ikon.
                    final url = ref.watch(myAvatarUrlProvider).value;
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: HomeTokens.tint(HomeTokens.primary),
                      backgroundImage: url != null
                          ? sinirliGorsel(context, NetworkImage(url), 40)
                          : null,
                      child: url == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 22,
                              color: HomeTokens.primary,
                            )
                          : null,
                    );
                  },
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: HomeTokens.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: s.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5 yuvali alt-bar — merkez yuva bar'in USTUNE tasan 56px mavi daire FAB,
/// digerleri ikon + etiket (aktif: dolgu ikon + mavi).
class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.role,
    required this.currentIndex,
    required this.unreadCount,
    required this.onDestinationSelected,
    required this.onBildir,
  });

  final UserRole role;
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onBildir;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final slots = homeShellSlots(context.l10n, role);

    // Bar YUKSEKLIGI yazi olcegiyle BUYUR: 64 dp sabit yukseklik 2.0x
    // olcekte etiketi 10 px tasiriyordu (tur 34 — ana ekran o zamana kadar
    // yalniz koyu tema ve klavye eksenlerinde surulmustu). Ust sinir 100:
    // bar ekrani yutmasin. Metni kucultmek yerine KUTUYU buyutmek dogru
    // secim — erisilebilirlik ayari kullanicinin talebidir.
    final barYuksekligi = MediaQuery.textScalerOf(context)
        .scale(HomeTokens.bottomBarHeight)
        .clamp(HomeTokens.bottomBarHeight, 100.0);

    return SizedBox(
      // FAB'in tasma payi + bar + cihaz alt guvenli alani.
      height:
          barYuksekligi +
          HomeTokens.fabOverflow +
          MediaQuery.of(context).padding.bottom,
      child: Stack(
        children: [
          // Bar zemini — tasma payinin ALTINDA baslar.
          Positioned(
            left: 0,
            right: 0,
            top: HomeTokens.fabOverflow,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s.card,
                border: Border(top: BorderSide(color: s.divider)),
              ),
            ),
          ),
          // Yuvalar — merkez yuva tasma payini da kaplar (FAB yukari cikar).
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < slots.length; i++)
                    Expanded(
                      child: slots[i].kind == HomeSlotKind.fab
                          ? _FabSlot(slot: slots[i], onTap: onBildir)
                          : _DestinationSlot(
                              slot: slots[i],
                              active: i == currentIndex,
                              // KIMLIK ile karar: etikete bakmak rozeti
                              // Turkce disi her dilde yok ederdi (tur 13).
                              badge: slots[i].id == HomeSlotId.bildirimler
                                  ? unreadCount
                                  : 0,
                              onTap: () => onDestinationSelected(i),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationSlot extends StatelessWidget {
  const _DestinationSlot({
    required this.slot,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final HomeSlot slot;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    // Etkin yuvanin ETIKETI de bu renkle cizilir; koyu temada ham vurgu
    // 11 punto icin 3.31:1 kaliyordu (tur 32).
    final color = active ? s.accentText(HomeTokens.primary) : s.muted;
    final iconWidget = Icon(
      active ? slot.activeIcon : slot.icon,
      size: 24,
      color: color,
    );
    return InkResponse(
      onTap: onTap,
      child: Padding(
        // Yuva icerigi bar zeminine hizalanir (tasma payi FAB'e ait).
        padding: const EdgeInsets.only(top: HomeTokens.fabOverflow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badge > 0
                ? Badge(
                    backgroundColor: HomeSurface.of(context).badge,
                    label: Text(
                      '$badge',
                      style: TextStyle(color: HomeSurface.of(context).badgeOn),
                    ),
                    child: iconWidget,
                  )
                : iconWidget,
            const SizedBox(height: 4),
            Text(
              slot.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.navLabel.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Merkez yuva: 56px mavi daire (bar'in ustune tasar). YAZI YOK.
///
/// (P154 / Asama 7.2) Brief: "'Olay bildir' butonundan yazi kaldirilsin,
/// sadece '+' kalsin".
///
/// ETIKET YOK OLMADI, YALNIZ GORUNMEZ OLDU. Ciplak bir "+" ekran
/// okuyucuya "dugme" der ve baska hicbir sey — kullanici neyi actigini
/// bilemez. Ad `Semantics`e tasindi, yani gorsel sadelesme bir
/// ERISILEBILIRLIK KAYBI DEGIL.
class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.slot, required this.onTap});

  final HomeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Semantics(
      button: true,
      label: slot.label,
      child: InkResponse(
        key: const Key('home-fab'),
        onTap: onTap,
        // `Center` SART: yuva bar icinde GENIS bir kutu aliyor ve
        // `Container` esnek kisitlari oldugu gibi benimsiyor — olculdu,
        // daire 56 yerine 160 piksel cizildi. Onceki hâlde bu isi
        // `Column(mainAxisSize: min)` yapiyordu; yazi kalkinca sutun da
        // gereksizlesti ama KISITLAMA gerekliligi kalkmadi.
        child: Center(
          child: Container(
            width: HomeTokens.fabSize,
            height: HomeTokens.fabSize,
            decoration: BoxDecoration(
              color: HomeTokens.primary,
              shape: BoxShape.circle,
              border: Border.all(color: s.card, width: 3),
            ),
            child: Icon(slot.icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
