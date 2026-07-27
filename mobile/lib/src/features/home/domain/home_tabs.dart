/// Ana ekran alt-navigasyonunun (HomeShell) SAF modeli — widget'siz, birim
/// testle dogrulanir. Referans tasarimlar (docs/design-refs) ile ayni yuva
/// dizilimi: 5 yuva — [Ana Sayfa] [Bildirimler] [merkez FAB] [Raporlar]
/// [Ayarlar]. Rota cozumu sunum katmaninda (rol-kapili menuden bagimsiz).
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';

/// Merkez "Bildir" FAB'inin etiketi. Referans alt-bar'da site sakini
/// "Talep / Bildir" (kendi talebini acar) gorurken diger tum roller
/// operasyonel "Olay Bildir" gorur (site-sakini.jpeg vs yonetici/gorevli.jpeg).
String fabLabelForRole(AppLocalizations l10n, UserRole role) =>
    role == UserRole.resident ? l10n.fabTalepBildir : l10n.fabOlayBildir;

/// Alt-bar yuvasinin turu: normal destinasyon (sekme) ya da merkez FAB.
enum HomeSlotKind { destination, fab }

/// Yuvanin DILDEN BAGIMSIZ kimligi. Alt-bar davranisi (orn. okunmamis
/// bildirim rozetinin hangi sekmeye basilacagi) buna bakar — ETIKETE DEGIL:
/// etiket aktif dile gore degisir (bkz. README §15, kimlik/metin ayrimi).
enum HomeSlotId { anaSayfa, bildirimler, bildir, raporlar, ayarlar }

/// Alt-bar tek yuvasi — ikon + etiket + tur. Rota cozumu sunum katmaninda.
class HomeSlot {
  const HomeSlot(this.id, this.kind, this.icon, this.label,
      {IconData? activeIcon})
      : activeIcon = activeIcon ?? icon;

  /// Dilden bagimsiz kimlik — karsilastirmalar BUNUNLA yapilir.
  final HomeSlotId id;

  final HomeSlotKind kind;

  /// Pasif ikon (referans: ince cizgi).
  final IconData icon;

  /// Aktif ikon (referans: DOLGU + mavi).
  final IconData activeIcon;

  final String label;
}

/// Referans alt-bar dizilimi: [Ana Sayfa] [Bildirimler] [merkez FAB]
/// [Raporlar] [Ayarlar]. Destinasyonlar rolden bagimsiz; yalniz merkez FAB
/// etiketi role gore degisir (bkz. [fabLabelForRole]).
///
/// ETIKETLER AKTIF DILDEN gelir ([l10n]) — yuva listesi artik `const`
/// degildir (metin cizim aninda cozulur).
List<HomeSlot> homeShellSlots(AppLocalizations l10n, UserRole role) => [
      HomeSlot(HomeSlotId.anaSayfa, HomeSlotKind.destination,
          Icons.home_outlined, l10n.sekmeAnaSayfa,
          activeIcon: Icons.home),
      HomeSlot(HomeSlotId.bildirimler, HomeSlotKind.destination,
          Icons.notifications_outlined, l10n.sekmeBildirimler,
          activeIcon: Icons.notifications),
      HomeSlot(HomeSlotId.bildir, HomeSlotKind.fab, Icons.add,
          fabLabelForRole(l10n, role)),
      HomeSlot(HomeSlotId.raporlar, HomeSlotKind.destination,
          Icons.insert_chart_outlined, l10n.sekmeRaporlar,
          activeIcon: Icons.insert_chart),
      HomeSlot(HomeSlotId.ayarlar, HomeSlotKind.destination,
          Icons.settings_outlined, l10n.sekmeAyarlar,
          activeIcon: Icons.settings),
    ];
