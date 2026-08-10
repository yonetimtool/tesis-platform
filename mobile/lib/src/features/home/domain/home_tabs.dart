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

/// (P154 / Asama 7.2) DORDUNCU YUVA ROLE GORE DEGISIR.
///
/// Brief: "Alt menu: yonetici -> 'Raporlar' · sakin -> 'Seffaflik' (ayni
/// sayfa) · guvenlik + tesis gorevlisi -> 'Gorevlerim'".
///
/// OLCULDU, hepsi gercek bosluktu:
///   * SAKIN zaten `/transparency`e gidiyordu ama etiket "Raporlar"
///     diyordu — kullanici tikladigi seyle gordugu seyi eslestiremiyor.
///   * SAHA rolleri icin yuva bir "yakinda" bildirimi gosteriyordu; yani
///     bes yuvanin biri onlar icin HICBIR ISE YARAMIYORDU. Oysa
///     "Gorevlerim" saha personelinin gunluk ekranidir.
///
/// KIMLIK DE DEGISIR, yalniz etiket degil: rota cozumu `HomeSlotId`e
/// bakar. Ayni kimligi tutup uc ekranda `switch` yazmak, yuvayi
/// degistiren birinin uc yeri de bulmasini gerektirirdi.
///
/// Yuvanin DILDEN BAGIMSIZ kimligi. Alt-bar davranisi (orn. okunmamis
/// bildirim rozetinin hangi sekmeye basilacagi) buna bakar — ETIKETE DEGIL:
/// etiket aktif dile gore degisir (bkz. README §15, kimlik/metin ayrimi).
enum HomeSlotId {
  anaSayfa,
  bildirimler,
  bildir,
  raporlar,
  seffaflik,
  gorevlerim,
  ayarlar,
}

/// Rolun dorduncu yuvasi. Switch EKSIKSIZ (default yok): yeni bir rol
/// eklenince derleyici burayi da doldurmaya zorlar.
HomeSlotId dorduncuYuva(UserRole role) => switch (role) {
  UserRole.resident => HomeSlotId.seffaflik,
  UserRole.security || UserRole.tesisGorevlisi => HomeSlotId.gorevlerim,
  _ => HomeSlotId.raporlar,
};

/// Alt-bar tek yuvasi — ikon + etiket + tur. Rota cozumu sunum katmaninda.
class HomeSlot {
  const HomeSlot(
    this.id,
    this.kind,
    this.icon,
    this.label, {
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;

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
  HomeSlot(
    HomeSlotId.anaSayfa,
    HomeSlotKind.destination,
    Icons.home_outlined,
    l10n.sekmeAnaSayfa,
    activeIcon: Icons.home,
  ),
  HomeSlot(
    HomeSlotId.bildirimler,
    HomeSlotKind.destination,
    Icons.notifications_outlined,
    l10n.sekmeBildirimler,
    activeIcon: Icons.notifications,
  ),
  HomeSlot(
    HomeSlotId.bildir,
    HomeSlotKind.fab,
    Icons.add,
    fabLabelForRole(l10n, role),
  ),
  _dorduncu(l10n, role),
  HomeSlot(
    HomeSlotId.ayarlar,
    HomeSlotKind.destination,
    Icons.settings_outlined,
    l10n.sekmeAyarlar,
    activeIcon: Icons.settings,
  ),
];

/// Dorduncu yuvanin ikonu + etiketi. Uc secenek de AYNI YERDE durur ki
/// biri degisince otekiler gozden kacmasin.
HomeSlot _dorduncu(AppLocalizations l10n, UserRole role) =>
    switch (dorduncuYuva(role)) {
      HomeSlotId.seffaflik => HomeSlot(
        HomeSlotId.seffaflik,
        HomeSlotKind.destination,
        Icons.visibility_outlined,
        l10n.sekmeSeffaflik,
        activeIcon: Icons.visibility,
      ),
      HomeSlotId.gorevlerim => HomeSlot(
        HomeSlotId.gorevlerim,
        HomeSlotKind.destination,
        Icons.fact_check_outlined,
        l10n.sekmeGorevlerim,
        activeIcon: Icons.fact_check,
      ),
      _ => HomeSlot(
        HomeSlotId.raporlar,
        HomeSlotKind.destination,
        Icons.insert_chart_outlined,
        l10n.sekmeRaporlar,
        activeIcon: Icons.insert_chart,
      ),
    };
