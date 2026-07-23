/// Ana ekran alt-navigasyonunun (HomeShell) SAF modeli — widget'siz, birim
/// testle dogrulanir. Referans tasarimlar (docs/design-refs) ile ayni yuva
/// dizilimi: 5 yuva — [Ana Sayfa] [Bildirimler] [merkez FAB] [Raporlar]
/// [Ayarlar]. Rota cozumu sunum katmaninda (rol-kapili menuden bagimsiz).
library;

import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';

/// Merkez "Bildir" FAB'inin etiketi. Referans alt-bar'da site sakini
/// "Talep / Bildir" (kendi talebini acar) gorurken diger tum roller
/// operasyonel "Olay Bildir" gorur (site-sakini.jpeg vs yonetici/gorevli.jpeg).
String homeBildirLabel(UserRole role) =>
    role == UserRole.resident ? 'Talep / Bildir' : 'Olay Bildir';

/// Alt-bar yuvasinin turu: normal destinasyon (sekme) ya da merkez FAB.
enum HomeSlotKind { destination, fab }

/// Alt-bar tek yuvasi — ikon + etiket + tur. Rota cozumu sunum katmaninda.
class HomeSlot {
  const HomeSlot(this.kind, this.icon, this.label);

  final HomeSlotKind kind;
  final IconData icon;
  final String label;
}

/// Referans alt-bar dizilimi: [Ana Sayfa] [Bildirimler] [merkez FAB]
/// [Raporlar] [Ayarlar]. Destinasyonlar rolden bagimsiz; yalniz merkez FAB
/// etiketi role gore degisir (bkz. [homeBildirLabel]).
List<HomeSlot> homeShellSlots(UserRole role) => [
      const HomeSlot(HomeSlotKind.destination, Icons.home_outlined, 'Ana Sayfa'),
      const HomeSlot(
          HomeSlotKind.destination, Icons.notifications_outlined, 'Bildirimler'),
      HomeSlot(HomeSlotKind.fab, Icons.add, homeBildirLabel(role)),
      const HomeSlot(
          HomeSlotKind.destination, Icons.insights_outlined, 'Raporlar'),
      const HomeSlot(
          HomeSlotKind.destination, Icons.settings_outlined, 'Ayarlar'),
    ];
