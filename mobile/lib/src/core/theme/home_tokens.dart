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

  /// Vurgularin KOYU tema karsiligi — YALNIZ METIN icin.
  ///
  /// Vurgu paleti tema-bagimsizdir cunku ANLAM tasir (yesil=olumlu,
  /// kirmizi=ihlal). Bu ikon ve dolgular icin dogru; METIN icin degil:
  /// 600-tonu vurgular koyu zeminde WCAG AA'yi tutmaz (tur 32 olcumu —
  /// #2563EB / #0F131A = 3.60:1, esik 4.5). Ayni RENK AILESININ acik tonu
  /// anlami korur ve kontrasti tutar (400-tonlari).
  static const _koyuMetin = <int, Color>{
    0xFF2563EB: Color(0xFF7CA9FF), // blue-600  → acik mavi
    0xFF16A34A: Color(0xFF4ADE80), // green-600 → green-400
    0xFFF59E0B: Color(0xFFFBBF24), // amber-500 → amber-400
    0xFF8B5CF6: Color(0xFFB69CFB), // violet-500→ acik mor
    0xFFEF4444: Color(0xFFFCA5A5), // red-500   → red-300
  };
}

/// Temaya gore cozulen yuzey + metin renkleri. Acik modda referans gorsellerin
/// tam degerleri; koyu modda ayni HIYERARSININ koyu karsiliklari (ana ekran
/// koyu temada da okunur kalir).
class HomeSurface {
  const HomeSurface({
    required this.background,
    required this.badge,
    required this.badgeOn,
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

  /// (P166 §7.2) ROZET DOLGUSU — TEMAYA GORE.
  ///
  /// Koyu tema bir kademe ACILINCA (#0F131A -> #1B222C) zil sayacinin
  /// kirmizisi (#EF4444) app bar zemininde 4.25'e dustu ve `flutter_test`
  /// kontrast denetimi bunu YAKALADI. Rozet ANLAM tasiyor (okunmamis
  /// bildirim) — soluklasmasi kabul edilemez.
  ///
  /// Koyu temada dolgu ACILIR ve uzerindeki metin KOYULASIR: ikisi
  /// birlikte degismek zorunda, yoksa acilan dolgunun ustunde beyaz metin
  /// okunamaz olurdu (#F26565 uzerinde beyaz 3.08).
  final Color badge;

  /// Rozet dolgusu uzerindeki metin rengi.
  final Color badgeOn;

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
    // (P166 §7.2) ZEMIN BIR KADEME KOYULASTI, KART BEYAZ KALDI.
    //
    // OLCULEN KUSUR: #F4F6FA zemin ile beyaz kart arasindaki kontrast
    // orani 1.03'tu — yani GORUNMEZ. "Acik tema fazla beyaz gorunuyor"
    // sikayetinin sebebi renklerin acikligi degil, kartin bir YUZEY gibi
    // degil zeminin devami gibi okunmasiydi. Yeni oran 1.16.
    background: Color(0xFFEAEEF5),
    badge: HomeTokens.red,
    badgeOn: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0x0A000000), // %4 siyah
    divider: Color(0xFFE4E9F1),
    heading: Color(0xFF111827),
    body: Color(0xFF374151),
    // Zemin koyulastigi icin YENIDEN OLCULDU: eski #6B7280 yeni zeminde
    // 4.15 ile AA'nin ALTINA duserdi. Ton korunup aciklik kaydirildi;
    // yeni deger zeminde 4.75, beyaz kartta 5.52.
    muted: Color(0xFF626976),
    placeholder: Color(0xFFE5E7EB),
  );

  static const _dark = HomeSurface(
    // (P166 §7.2) KOYU TEMA BIR KADEME YUKSELTILDI.
    //
    // #0F131A neredeyse siyahti ve kartla arasi 1.09 — uc katman da ayni
    // karanlikta okunuyordu ("koyu tema fazla koyu"). Yeni oran 1.17;
    // kart artik zeminden GORUNUR sekilde yukselir. Metin tonlari
    // yeniden olculdu: hepsi AA'yi tutuyor (baslik 12.4, govde 9.3,
    // ikincil 5.4 — kart uzerinde).
    background: Color(0xFF1B222C),
    // Olculdu: dolgu/zemin 5.20, metin/dolgu 5.20 — ikisi de AA.
    badge: Color(0xFFF26565),
    badgeOn: Color(0xFF1B222C),
    card: Color(0xFF262E3A),
    cardBorder: Color(0x14FFFFFF),
    divider: Color(0xFF333C4A),
    heading: Color(0xFFF3F4F6),
    body: Color(0xFFD1D5DB),
    muted: Color(0xFF9CA3AF),
    placeholder: Color(0xFF333C4A),
  );

  /// Vurgu renginin BU YUZEYDE metin olarak kullanilacak bicimi.
  ///
  /// Acik temada vurgu aynen doner; koyu temada acik tonu (bkz.
  /// [HomeTokens._koyuMetin]). Ikon/dolgu/tint icin ham vurgu kullanilmaya
  /// devam eder — sorun yalniz METIN kontrastindadir.
  Color accentText(Color accent) =>
      koyu ? (HomeTokens._koyuMetin[accent.toARGB32()] ?? accent) : accent;

  /// Bu yuzey koyu tema mi? (`accentText` disinda cagri yerlerinde de
  /// tema sorgulamak yerine buradan okunur.)
  bool get koyu => background == _dark.background;

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

  /// ALT BAR etiketi — 12 (chip'ten 1 punto buyuk).
  ///
  /// Neden ayri: 11 puntoda KOYU temada Kiril/Arap harfleri okunacak MUREKKEP
  /// YOGUNLUGUNA ulasmiyor — tur 32 olcumu ayni renkte "Ana Sayfa"yi gecirip
  /// "Главная"yi 2.18 ile dusurdu. Rengi beyaza kadar acmak (denendi: #C7D9FF
  /// hala 3.64) markayi yok ederdi; 12 punto ise TUM dillerde gecti. Alt bar
  /// etiketi zaten en kucuk kalici metindi.
  static const navLabel = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2);

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

/// Herhangi bir VURGU renginin, o temada METIN olarak okunur bicimi.
///
/// [HomeSurface.accentText] ana ekranin SABIT paletini elle esler; buradaki
/// surum KEYFI renkler icindir (gorev kategorisi, durum cipi, hata bandi...).
///
/// IKI YONLU (tur 57). Ilk surum (tur 37) yalniz KOYU temayi duzeltiyordu;
/// olcum acik temanin de basarisiz oldugunu gosterdi. "Tint zemin" kalibinda
/// — zemin = ayni rengin %8-15 opakligi — HAM renk METIN olarak:
///
///   renk              acik tema   koyu tema
///   Colors.orange       1.92        6.07
///   Colors.green        2.42        4.92
///   Colors.blue         2.66        4.49
///   Colors.red          3.03        3.98
///   HomeTokens.primary  4.20        2.91
///   indigo #3949AB      6.11        2.03
///
/// Esik 4.5 — yani cogu kombinasyon IKI TEMADA da okunmuyordu. Donusum:
///   * acik tema: rengi KOYULASTIR (L -0.22, 0.24-0.34 bandina sikistir)
///   * koyu tema: rengi ACIKLASTIR (L +0.35, 0.68-0.90 bandina)
/// Ton (hue) korunur — yesil=olumlu / kirmizi=ihlal anlami bozulmaz. Yedi
/// vurgu rengi de bu donusumle iki temada 5.4:1 uzerine cikar.
///
/// ZEMIN icin kullanilmaz: dolgu ham renk tintiyle kalir.
Color okunurVurgu(BuildContext context, Color vurgu) {
  final koyu = Theme.of(context).brightness == Brightness.dark;
  final h = HSLColor.fromColor(vurgu);
  return koyu
      ? h
          .withLightness((h.lightness + 0.35).clamp(0.68, 0.9))
          .withSaturation((h.saturation * 0.85).clamp(0.0, 1.0))
          .toColor()
      : h
          .withLightness((h.lightness - 0.22).clamp(0.24, 0.34))
          .withSaturation((h.saturation * 1.05).clamp(0.0, 1.0))
          .toColor();
}


/// YIKICI EYLEM (silme) dugmesi stili — tur 40.
///
/// Onceden `backgroundColor: Colors.red` yaziliyordu. Iki sorunu vardi:
///   * #F44336 uzerinde BEYAZ yazi 3.99:1 — WCAG AA esigi (14 punto) 4.5;
///   * renk TEMA-BAGIMSIZDI: koyu temada kirmizi dolgu koyu yuzeyle
///     karisiyor, dugme kendi zemininden zor ayirt ediliyordu.
///
/// M3'un `colorScheme.error` / `onError` cifti ikisini de tema basina
/// cozer (koyu temada acik kirmizi zemin + koyu yazi). Silme dugmelerinin
/// TAMAMI bunu kullanir — tek kaynak.
ButtonStyle yikiciDugmeStili(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: cs.error,
    foregroundColor: cs.onError,
  );
}
