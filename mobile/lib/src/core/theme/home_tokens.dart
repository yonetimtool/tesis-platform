/// Ana ekran tasarim TOKEN'lari — referans gorseller (docs/design-refs:
/// gorevli.jpeg / site-sakini.jpeg / yonetici.jpeg) icin TEK KAYNAK.
///
/// Ekranlarda ve bolum widget'larinda ham renk/olcu YAZILMAZ; hepsi buradan
/// okunur. Vurgu (accent) renkleri iki temada da AYNI kalir — anlam tasirlar
/// (yesil=olumlu, kirmizi=ihlal...). Yuzey/metin renkleri temaya gore cozulur
/// ([HomeSurface.of]) — koyu mod ana ekrani beyaz kart tokenlariyla
/// yakmamak icin.
library;

import 'package:flutter/material.dart';

/// Vurgu paleti + olcu sabitleri. Tema-bagimsiz (iki modda ayni).
class HomeTokens {
  const HomeTokens._();

  // ---------------------------------------------------------------- renkler
  /// Ana mavi — aktif sekme, FAB, "Tümünü Gör", birincil kart vurgusu.
  static const primary = Color(0xFF2563EB);
  static const green = Color(0xFF16A34A);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const red = Color(0xFFEF4444);

  /// Rozet/uyari kirmizisi (zil sayaci) — vurgu kirmizisiyla ayni.
  static const badge = red;

  /// Online noktasi (avatar + vardiya karti).
  static const online = green;

  // ----------------------------------------------------------------- olcu
  /// Kart yariçapi (tum beyaz kartlar).
  static const cardRadius = 16.0;

  /// Kart ici standart bosluk.
  static const cardPadding = 16.0;

  /// Ikon konteyneri: 56x56, radius 14, tint zemin, ortada 26px accent ikon.
  static const iconBox = 56.0;
  static const iconBoxRadius = 14.0;
  static const iconSize = 26.0;

  /// "Son Hareketler" satirindaki kucuk yuvarlak ikon.
  static const rowIconBox = 40.0;

  /// Chip/rozet yariçapi.
  static const chipRadius = 8.0;

  /// Bolumler arasi dikey bosluk.
  static const sectionGap = 20.0;

  /// Izgara/serit hucreleri arasi bosluk.
  static const gridGap = 12.0;

  /// Hizli erisim seridi (gorevli) kart genisligi.
  static const stripCardWidth = 110.0;

  /// Vardiya karti genisligi.
  static const shiftCardWidth = 150.0;

  /// Alt bar yuksekligi (FAB bunun uzerine tasar).
  static const bottomBarHeight = 64.0;

  /// Merkez FAB capi.
  static const fabSize = 56.0;

  /// FAB'in alt bar ustune tasma miktari.
  static const fabOverflow = 18.0;

  /// Accent'in "tint" zemini — %12 opaklik (brief: %10-12).
  static Color tint(Color accent) => accent.withValues(alpha: 0.12);
}

/// Temaya gore cozulen yuzey + metin renkleri. Acik modda referans gorsellerin
/// tam degerleri; koyu modda ayni HIYERARSININ koyu karsiliklari (ana ekran
/// koyu temada da okunur kalir).
class HomeSurface {
  const HomeSurface({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.divider,
    required this.heading,
    required this.body,
    required this.muted,
    required this.placeholder,
  });

  /// Sayfa zemini.
  final Color background;

  /// Kart zemini.
  final Color card;

  /// Kart kenarligi — gorsellerde golge yerine cok hafif cizgi (1px, %4 siyah).
  final Color cardBorder;

  /// Liste satirlari arasi 1px ayrac.
  final Color divider;

  /// Baslik metni.
  final Color heading;

  /// Govde metni.
  final Color body;

  /// Ikincil/gri metin.
  final Color muted;

  /// Gorsel yer tutucu zemini (duyuru foto, kamera karesi).
  final Color placeholder;

  static const _light = HomeSurface(
    background: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0x0A000000), // %4 siyah
    divider: Color(0xFFF1F2F6),
    heading: Color(0xFF111827),
    body: Color(0xFF374151),
    muted: Color(0xFF6B7280),
    placeholder: Color(0xFFE5E7EB),
  );

  static const _dark = HomeSurface(
    background: Color(0xFF0F131A),
    card: Color(0xFF171C25),
    cardBorder: Color(0x14FFFFFF),
    divider: Color(0xFF232A36),
    heading: Color(0xFFF3F4F6),
    body: Color(0xFFD1D5DB),
    muted: Color(0xFF9CA3AF),
    placeholder: Color(0xFF232A36),
  );

  static HomeSurface of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// Standart beyaz kart kaplamasi — radius 16 + 1px cok hafif kenarlik
  /// (gorsellerde golge yok denecek kadar hafif; kenarlik tutarli secildi).
  BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
        border: Border.all(color: cardBorder),
      );
}

/// Referans tipografi olcegi. Renk cagri yerinde [HomeSurface]'ten verilir —
/// boylece ayni olcek iki temada da calisir.
class HomeText {
  const HomeText._();

  /// "Merhaba, Kerem" — 26 bold.
  static const greeting =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15);

  /// Selamlamanin alt satiri — 14.
  static const greetingSub = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);

  /// Bolum basligi — 18 bold.
  static const section = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

  /// "Tümünü Gör ›" — 14 medium, primary.
  static const link = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, color: HomeTokens.primary);

  /// Kart basligi — 14 semibold.
  static const cardTitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);

  /// Kart alt metni / sayac — 12-13.
  static const cardCounter =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

  /// Liste satiri alt metni — 12.
  static const rowSub = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  /// Chip/rozet — 11 semibold.
  static const chip = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2);

  /// Istatistik degeri — 20 bold.
  static const statValue =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1);

  /// Istatistik etiketi — 13 semibold.
  static const statLabel =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// Buyuk para degeri (aidat karti) — 22 bold.
  static const money =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.15);
}
