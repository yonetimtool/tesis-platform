import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'section_padding.dart';

/// Referans "hizli erisim" karti — beyaz kart, ortada tint ikon konteyneri,
/// altinda 14 semibold baslik ve accent/gri sayac satiri. gorevli.jpeg'in
/// yatay seridi ile sakin/yonetici 4x2 izgarasi AYNI kart tipini kullanir;
/// fark yalniz hucre genisligidir.
///
/// Ikon konteyneri spesifikasyonda 56x56'dir; bu olcu seritte (110dp kart)
/// birebir uygulanir. 4 sutunlu izgarada hucre ~80dp'ye duser ve 56dp kutu
/// karti bogar — orada kutu hucre genisliginin ~%45'ine olceklenir
/// (referans gorseldeki ikon/kart oraniyla ayni), boylece izgara telefonda da
/// gorselle ayni dengeyi korur.
class HizliErisimKarti extends StatelessWidget {
  const HizliErisimKarti({
    super.key,
    required this.kart,
    required this.onTap,
    this.hucreGenisligi,
    this.baslikGrubu,
    this.sayacGrubu,
  });

  final HizliErisimKart kart;

  /// Dokunma — rotasi olmayan (mock) kartlarda da cagrilir; hedefi cagiran
  /// katman belirler (ekranda "yakında" bilgilendirmesi).
  final VoidCallback onTap;

  /// Ikon kutusunu olceklemek icin hucre genisligi; null → 56 (serit).
  final double? hucreGenisligi;

  /// Ayni bolumdeki kartlarin tipografisini TEK TIP yapan gruplar.
  final AutoSizeGroup? baslikGrubu;
  final AutoSizeGroup? sayacGrubu;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final kutu = hucreGenisligi == null
        ? HomeTokens.iconBox
        : (hucreGenisligi! * 0.42).clamp(32.0, HomeTokens.iconBox);
    final ikonBoyut = kutu >= HomeTokens.iconBox
        ? HomeTokens.iconSize
        : (kutu * 0.55).clamp(17.0, HomeTokens.iconSize);

    return HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HomeIconBox(
            icon: kart.ikon,
            accent: kart.accent,
            size: kutu,
            iconSize: ikonBoyut,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: AutoSizeText(
              kart.baslik,
              group: baslikGrubu,
              maxLines: 2,
              minFontSize: 8,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: HomeText.cardTitle.copyWith(color: s.heading),
            ),
          ),
          const SizedBox(height: 3),
          AutoSizeText(
            kart.altMetin,
            group: sayacGrubu,
            maxLines: 1,
            minFontSize: 8,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: HomeText.cardCounter
                .copyWith(color: kart.altMetinRengi ?? kart.accent),
          ),
          if (kart.ikinciAltMetin != null)
            AutoSizeText(
              kart.ikinciAltMetin!,
              group: sayacGrubu,
              maxLines: 1,
              minFontSize: 9,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: HomeText.cardCounter.copyWith(
                color: kart.ikinciAltMetinRengi ?? HomeTokens.green,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// gorevli.jpeg — TEK SIRA yatay kaydirilabilir serit (5 kart, ~110dp).
class HizliErisimSeridi extends StatelessWidget {
  const HizliErisimSeridi({
    super.key,
    required this.kartlar,
    required this.onSec,
  });

  final List<HizliErisimKart> kartlar;
  final ValueChanged<HizliErisimKart> onSec;

  @override
  Widget build(BuildContext context) {
    if (kartlar.isEmpty) return const SizedBox.shrink();
    final baslikGrubu = AutoSizeGroup();
    final sayacGrubu = AutoSizeGroup();

    return LayoutBuilder(builder: (context, c) {
      final genislik = seritKartGenisligi(c.maxWidth);
      return SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kHomePagePadding),
          itemCount: kartlar.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: HomeTokens.gridGap),
          itemBuilder: (context, i) => SizedBox(
            width: genislik,
            child: HizliErisimKarti(
              kart: kartlar[i],
              onTap: () => onSec(kartlar[i]),
              hucreGenisligi: genislik,
              baslikGrubu: baslikGrubu,
              sayacGrubu: sayacGrubu,
            ),
          ),
        ),
      );
    });
  }
}

/// site-sakini.jpeg / yonetici.jpeg — 4 sutun x 2 satir SABIT izgara
/// (kaydirma yok). Cok dar ekranda (<=360dp) 4 sutun okunmaz hale geldigi
/// icin 2 sutuna duser — icerik ve sira aynidir.
class HizliErisimIzgarasi extends StatelessWidget {
  const HizliErisimIzgarasi({
    super.key,
    required this.kartlar,
    required this.onSec,
  });

  final List<HizliErisimKart> kartlar;
  final ValueChanged<HizliErisimKart> onSec;

  @override
  Widget build(BuildContext context) {
    if (kartlar.isEmpty) return const SizedBox.shrink();
    final baslikGrubu = AutoSizeGroup();
    final sayacGrubu = AutoSizeGroup();

    return LayoutBuilder(builder: (context, c) {
      final sutun = hizliErisimSutun(c.maxWidth);
      final hucre =
          (c.maxWidth - HomeTokens.gridGap * (sutun - 1)) / sutun;
      return GridView.count(
        crossAxisCount: sutun,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: HomeTokens.gridGap,
        crossAxisSpacing: HomeTokens.gridGap,
        childAspectRatio: hizliErisimOran(sutun),
        children: [
          for (final k in kartlar)
            HizliErisimKarti(
              kart: k,
              onTap: () => onSec(k),
              hucreGenisligi: hucre,
              baslikGrubu: baslikGrubu,
              sayacGrubu: sayacGrubu,
            ),
        ],
      );
    });
  }
}

/// Izgara sutun sayisi — referans 4. Esik IZGARANIN kendi genisligine gore
/// olculur (ekran genisligi degil; bolum yatay bosluklarindan sonra kalan
/// alan): 300dp altinda 4 sutun hucresi ~66dp'ye dustugu icin okunmaz hale
/// gelir, orada 2'ye duser. Tipik telefon (>=360dp ekran → >=328dp izgara)
/// referanstaki gibi 4 sutundur.
int hizliErisimSutun(double maxWidth) => maxWidth < 300 ? 2 : 4;

/// Hucre en/boy orani. 4 sutunda hucre dardir (ikon + 2 satir baslik +
/// sayac) → dikey dikdortgen; 2 sutunda genis hucre neredeyse kare.
double hizliErisimOran(int sutun) => sutun == 4 ? 0.70 : 1.15;

/// Yatay seritteki (gorevli) kart genisligi.
///
/// Spesifikasyon ~110dp der; referans gorselde ise 5 kartin TAMAMI ekrana
/// sigar. Ikisi ayni artboard'dan gelir ve telefon genisliginde ayni anda
/// saglanamaz (5x110 + bosluklar ~610dp eder). Uzlasma: kart, seritte ~4.5
/// kart gorunecek sekilde olceklenir — referanstaki yogunluga yaklasir, 5.
/// kart kenardan "gozukur" (serit kaydirilabilir kaldigi icin spesifikasyona
/// da sadik). Genis ekranda spesifikasyonun 110dp'sine oturur.
double seritKartGenisligi(double maxWidth) {
  final kullanilabilir = maxWidth - kHomePagePadding * 2;
  final hedef = (kullanilabilir - HomeTokens.gridGap * 3.5) / 4.5;
  return hedef.clamp(84.0, HomeTokens.stripCardWidth);
}
