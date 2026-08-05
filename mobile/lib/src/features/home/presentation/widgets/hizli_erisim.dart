import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_kart_id.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'home_states.dart';
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
    final l10n = context.l10n;
    // Sayac YOKSA sabit etiket (varsa) gosterilir; ikisi de yoksa iskelet.
    final altSatir =
        kart.altMetin ??
        (kart.etiketId == null ? null : kartEtiketi(l10n, kart.etiketId!));
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
              kart.baslik(l10n),
              group: baslikGrubu,
              maxLines: 2,
              minFontSize: 8,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: HomeText.cardTitle.copyWith(color: s.heading),
            ),
          ),
          const SizedBox(height: 3),
          // Sayac YOKKEN (gercek uc henuz yuklenmedi) uydurma sayi degil,
          // notr iskelet cizilir — kart yuksekligi degismez.
          //
          // (P139.4) AMA "SAYACI YOK" ILE "VERI HENUZ YOK" AYRI SEYLER.
          // Kullanicinin sectigi bir karonun sayaci hic olmayabilir;
          // ayrim yapilmasaydi o karo SONSUZA KADAR iskelet cizerdi.
          // `sayacsiz` kartta iskelet YERINE ayni yukseklikte bos alan
          // birakilir — izgarada kart yuksekligi bozulmasin.
          if (kart.sayacsiz)
            const SizedBox(height: HomeSayacIskeleti.yukseklik)
          else if (altSatir == null)
            const HomeSayacIskeleti()
          else
            AutoSizeText(
              altSatir,
              group: sayacGrubu,
              maxLines: 1,
              minFontSize: 8,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: HomeText.cardCounter.copyWith(
                color: s.accentText(kart.altMetinRengi ?? kart.accent),
              ),
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
class HizliErisimSeridi extends StatefulWidget {
  const HizliErisimSeridi({
    super.key,
    required this.kartlar,
    required this.onSec,
  });

  final List<HizliErisimKart> kartlar;
  final ValueChanged<HizliErisimKart> onSec;

  @override
  State<HizliErisimSeridi> createState() => _HizliErisimSeridiState();
}

class _HizliErisimSeridiState extends State<HizliErisimSeridi> {
  // TITREME KURALI: gruplar STATE'te durur, `build()` icinde URETILMEZ.
  // Gerekce icin [HizliErisimIzgarasi] uzerindeki nota bakin.
  final baslikGrubu = AutoSizeGroup();
  final sayacGrubu = AutoSizeGroup();

  @override
  Widget build(BuildContext context) {
    final kartlar = widget.kartlar;
    if (kartlar.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final genislik = seritKartGenisligi(c.maxWidth);
        return SizedBox(
          // YAZI OLCEGIYLE BUYUR (tur 34).
          height: seritYuksekligi(context, 148),
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
                onTap: () => widget.onSec(kartlar[i]),
                hucreGenisligi: genislik,
                baslikGrubu: baslikGrubu,
                sayacGrubu: sayacGrubu,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// site-sakini.jpeg / yonetici.jpeg — 4 sutun x 2 satir SABIT izgara
/// (kaydirma yok). Cok dar ekranda (<=360dp) 4 sutun okunmaz hale geldigi
/// icin 2 sutuna duser — icerik ve sira aynidir.
///
/// NEDEN StatefulWidget (yalniz [AutoSizeGroup] icin): grup, uyelerinin ORTAK
/// yazi boyutunu tutan KALICI bir denetleyicidir ve ilk karede boyutu henuz
/// bilinmez — uyeler kendi boyutlarinda cizilir, grup en kucugunu bulunca bir
/// mikrogorev ile hepsini yeniden cizdirir. Grup `build()` icinde uretilirse
/// bu "bir kare sapma" HER yeniden cizimde tekrarlanir (sayac degeri
/// degismese bile: 45 sn'lik periyodik yenileme, dil/tema degisimi...) ve
/// kart yazilari gozle gorulur bicimde ziplar. Gruplari state'te tutmak
/// kimliklerini sabitler; `AutoSizeText.didUpdateWidget` grubu "degismis"
/// saymaz, ortak boyut korunur. Regresyon: home_kart_titremesi_test.dart.
class HizliErisimIzgarasi extends StatefulWidget {
  const HizliErisimIzgarasi({
    super.key,
    required this.kartlar,
    required this.onSec,
  });

  final List<HizliErisimKart> kartlar;
  final ValueChanged<HizliErisimKart> onSec;

  @override
  State<HizliErisimIzgarasi> createState() => _HizliErisimIzgarasiState();
}

class _HizliErisimIzgarasiState extends State<HizliErisimIzgarasi> {
  // TITREME KURALI: gruplar STATE'te durur, `build()` icinde URETILMEZ.
  final baslikGrubu = AutoSizeGroup();
  final sayacGrubu = AutoSizeGroup();

  @override
  Widget build(BuildContext context) {
    final kartlar = widget.kartlar;
    if (kartlar.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final sutun = hizliErisimSutun(c.maxWidth);
        final hucre = (c.maxWidth - HomeTokens.gridGap * (sutun - 1)) / sutun;
        return GridView.count(
          crossAxisCount: sutun,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: HomeTokens.gridGap,
          crossAxisSpacing: HomeTokens.gridGap,
          childAspectRatio: izgaraOrani(context, hizliErisimOran(sutun)),
          children: [
            for (final k in kartlar)
              HizliErisimKarti(
                kart: k,
                onTap: () => widget.onSec(k),
                hucreGenisligi: hucre,
                baslikGrubu: baslikGrubu,
                sayacGrubu: sayacGrubu,
              ),
          ],
        );
      },
    );
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

/// IZGARA HUCRE ORANI (tur 34) — sabit en/boy orani metin buyudugunde ya da
/// ekran daraldiginda hucreyi KISA birakir ve icerik tasar. Oran iki etkenle
/// kucultulur (hucre uzar): yazi olcegi ve dar ekran (320 dp'de basliklar
/// daha cok satira sarar). Alt sinir hucrenin ekrani yutmasini onler.
double izgaraOrani(BuildContext context, double taban) {
  final olcek = MediaQuery.textScalerOf(context).scale(1.0);
  final dar = MediaQuery.sizeOf(context).width < 360 ? 0.78 : 1.0;
  return (taban * dar / olcek).clamp(taban * 0.30, taban);
}

/// Yatay seritteki (gorevli) kart genisligi.
///
/// Spesifikasyon ~110dp der; referans gorselde ise 5 kartin TAMAMI ekrana
/// sigar. Ikisi ayni artboard'dan gelir ve telefon genisliginde ayni anda
/// saglanamaz (5x110 + bosluklar ~610dp eder). Uzlasma: kart, seritte ~4.5
/// kart gorunecek sekilde olceklenir — referanstaki yogunluga yaklasir, 5.
/// kart kenardan "gozukur" (serit kaydirilabilir kaldigi icin spesifikasyona
/// da sadik). Genis ekranda spesifikasyonun 110dp'sine oturur.
/// YATAY SERIT YUKSEKLIGI (tur 34).
///
/// Sabit yukseklikli seritler iki durumda tasiyordu: (1) yazi olcegi 2.0x —
/// metin buyur, kutu buyumez; (2) 320 dp — kart daralir, basliklar daha cok
/// satira sarar. Ikisi de eklenir; ust sinir seridin ekrani yutmasini onler.
double seritYuksekligi(BuildContext context, double taban) {
  final dar = MediaQuery.sizeOf(context).width < 360 ? 40.0 : 0.0;
  return MediaQuery.textScalerOf(
    context,
  ).scale(taban + dar).clamp(taban + dar, (taban + dar) * 1.8);
}

double seritKartGenisligi(double maxWidth) {
  final kullanilabilir = maxWidth - kHomePagePadding * 2;
  final hedef = (kullanilabilir - HomeTokens.gridGap * 3.5) / 4.5;
  return hedef.clamp(84.0, HomeTokens.stripCardWidth);
}
