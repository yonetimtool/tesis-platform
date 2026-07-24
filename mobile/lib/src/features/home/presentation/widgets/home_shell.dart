import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/home_tabs.dart';

/// Referans ana ekranin iskeleti: ust app-bar (marka logosu + bildirim zili
/// [rozetli] + avatar) + govde slotu + 5 yuvali alt-bar ([homeShellSlots] —
/// merkez [index 2] kabarik FAB). Rota cozumu DISARIDA: [onDestinationSelected]
/// yuva indeksini verir, merkez FAB [onBildir]'i cagirir (Bildirimler rotasi ve
/// role-gore Raporlar hedefi henuz sabit degil — cagrilan katman karar verir).
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.role,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onBildir,
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

  /// Hesap menusu "Profil" secildi.
  final VoidCallback? onProfile;

  /// Hesap menusu "Çıkış Yap" secildi (WP2.2 — her rolde erisilir; oturumu
  /// temizleyip login'e doner).
  final VoidCallback? onLogout;

  /// Bildirim zili rozet sayisi (0 → rozet yok).
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: YonetioMasterLogo(size: 30)),
        ),
        leadingWidth: 54,
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => onDestinationSelected(1),
            icon: unreadCount > 0
                ? Badge(
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
            child: Builder(builder: (context) => InkResponse(
              key: const Key('home-avatar'),
              // Referans: avatar hesap menusunu acar (Profil + Çıkış Yap).
              onTap: () => _hesapMenusu(context),
              radius: 22,
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    YonetioColors.navy.withValues(alpha: 0.12),
                child: const Icon(Icons.person_outline,
                    size: 20, color: YonetioColors.navy),
              ),
            )),
          ),
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
              leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
              title: const Text('Çıkış Yap',
                  style: TextStyle(color: Color(0xFFDC2626))),
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

/// 5 yuvali alt-bar — merkez yuva (2) kabarik FAB, digerleri ikon+etiket.
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
    final slots = homeShellSlots(role);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 68,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < slots.length; i++)
              Expanded(
                child: slots[i].kind == HomeSlotKind.fab
                    ? _FabSlot(slot: slots[i], onTap: onBildir)
                    : _DestinationSlot(
                        slot: slots[i],
                        active: i == currentIndex,
                        badge: slots[i].label == 'Bildirimler' ? unreadCount : 0,
                        onTap: () => onDestinationSelected(i),
                      ),
              ),
          ],
        ),
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
    final color =
        active ? YonetioColors.navy : Theme.of(context).hintColor;
    final iconWidget = Icon(slot.icon, size: 24, color: color);
    return InkResponse(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          badge > 0
              ? Badge(label: Text('$badge'), child: iconWidget)
              : iconWidget,
          const SizedBox(height: 4),
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.slot, required this.onTap});

  final HomeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      key: const Key('home-fab'),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: YonetioColors.navy,
              shape: BoxShape.circle,
            ),
            child: Icon(slot.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 2),
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: YonetioColors.navy,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
