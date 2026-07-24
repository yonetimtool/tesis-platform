import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../../auth/domain/user_role.dart';
import '../../../profile/data/avatar_api.dart';
import '../../domain/home_tabs.dart';
import 'home_drawer.dart';
import 'home_marka.dart';

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
class HomeShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
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
          _ZilButonu(
            unreadCount: unreadCount,
            onTap: () => onDestinationSelected(1),
          ),
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil'),
              onTap: () {
                Navigator.of(ctx).pop();
                onProfile?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: HomeTokens.red),
              title: const Text('Çıkış Yap',
                  style: TextStyle(color: HomeTokens.red)),
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
      tooltip: 'Bildirimler',
      onPressed: onTap,
      icon: unreadCount > 0
          ? Badge(
              backgroundColor: HomeTokens.badge,
              label: Text('$unreadCount'),
              child: Icon(Icons.notifications_outlined, color: s.heading),
            )
          : Icon(Icons.notifications_outlined, color: s.heading),
    );
  }
}

/// 40px yuvarlak avatar + sag altinda yesil online noktasi.
class _AvatarButonu extends StatelessWidget {
  const _AvatarButonu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return InkResponse(
      key: const Key('home-avatar'),
      onTap: onTap,
      radius: 26,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Consumer(builder: (context, ref, _) {
              // Personel avatari varsa resimli goster; yoksa/hata varsa ikon
              // fallback (ekran dusmez). Resident'ta uc 403 -> null -> ikon.
              final url = ref.watch(myAvatarUrlProvider).value;
              return CircleAvatar(
                radius: 20,
                backgroundColor: HomeTokens.tint(HomeTokens.primary),
                backgroundImage: url != null ? NetworkImage(url) : null,
                child: url == null
                    ? const Icon(Icons.person_outline,
                        size: 22, color: HomeTokens.primary)
                    : null,
              );
            }),
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
    final slots = homeShellSlots(role);

    return SizedBox(
      // FAB'in tasma payi + bar + cihaz alt guvenli alani.
      height: HomeTokens.bottomBarHeight +
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
                              badge: slots[i].label == 'Bildirimler'
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
    final color = active ? HomeTokens.primary : s.muted;
    final iconWidget =
        Icon(active ? slot.activeIcon : slot.icon, size: 24, color: color);
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
                    backgroundColor: HomeTokens.badge,
                    label: Text('$badge'),
                    child: iconWidget,
                  )
                : iconWidget,
            const SizedBox(height: 4),
            Text(
              slot.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.chip.copyWith(
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

/// Merkez yuva: 56px mavi daire (bar'in ustune tasar) + altinda etiket.
class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.slot, required this.onTap});

  final HomeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return InkResponse(
      key: const Key('home-fab'),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: HomeTokens.fabSize,
            height: HomeTokens.fabSize,
            decoration: BoxDecoration(
              color: HomeTokens.primary,
              shape: BoxShape.circle,
              border: Border.all(color: s.card, width: 3),
            ),
            child: Icon(slot.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.chip.copyWith(
              color: HomeTokens.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
