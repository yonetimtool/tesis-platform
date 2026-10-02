import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/ui/kelime_bolunmez.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_kart_id.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'home_states.dart';
import 'section_padding.dart';
import '../../../../core/gorunum/gorunum_modu.dart';

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
            // (P239 §1) PUNTO EN UZUN KELIMEYE GORE SECILIR.
            //
            // `AutoSizeText` puntoyu METNIN TAMAMI iki satira sigsin diye
            // secer; bir kelime satira sigmayinca Flutter onu ICINDEN
            // boler ve metin yine "sigmis" olur — AutoSizeText'e gore
            // sorun yoktur. Kusur ("Görüntülem / e İzni") tam buydu.
            //
            // Tavan burada BASTIRILIR: en uzun bolunmez parca satira
            // sigacak sekilde. AutoSizeText bundan yalnizca DAHA KUCUGE
            // inebilir, kucukte de kelime bolunmez. Grup (`baslikGrubu`)
            // KORUNUR — kartlarin ortak puntosu ve titremesizlik
            // (home_kart_titremesi_test) bozulmaz.
            //
            // (P247 §7) KURAL ARTIK TEK BILESENDE (`KartEtiketi`): olcum
            // CIZILEN stille yapilir (iOS'ta "Rezervasyo / n" kusuru olcum
            // ile cizimin farkli stil kullanmasiydi) ve ayni kural "Hizli
            // Ozet" kutularina da uygulanir.
            child: KartEtiketi(
              kart.baslik(l10n),
              grup: baslikGrubu,
              stil: HomeText.cardTitle.copyWith(color: s.heading),
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
            // SAYACSIZ KART, SAYAC SATIRININ YERINI AYNI WIDGET'LA tutar.
            //
            // UC DENEME GEREKTI ve ucuncusunun sebebi olculdu: sayac
            // satiri `AutoSizeText` ve bir GRUBA baglidir (`sayacGrubu`)
            // — grup, kartlarin yazi boyutunu birbirine gore olcekler.
            // Duz `Text` ya da `SizedBox` o gruba GIRMEDIGI icin geometri
            // kayiyor ve 320dp'de 0.36 piksel tasma uretiyordu (fotografli
            // dar-ekran surusu yakaladi). Ayni widget + ayni grup =
            // birebir ayni yukseklik.
            AutoSizeText(
              ' ',
              group: sayacGrubu,
              maxLines: 1,
              minFontSize: 8,
              style: HomeText.cardCounter.copyWith(
                color: const Color(0x00000000),
              ),
            )
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
    this.mod = GorunumModu.standart,
    this.onSiraDegisti,
  });

  /// (P251 §11) BASILI TUT, SURUKLE, BIRAK — yeni sira (TUM liste).
  ///
  /// `null` ise surukleme kapali (onizleme/test cizimleri). Kisa dokunus
  /// her zaman [onSec]; surukleme yalniz uzun basista baslar, yani
  /// sayfayi kaydirmak bir karti yerinden oynatmaz. Ekran okuyucu
  /// kullanicisi surukleyemez: her karoda "Yukari tasi / Asagi tasi"
  /// eylemleri ayni geri cagirmaya gider.
  final ValueChanged<List<HizliErisimKart>>? onSiraDegisti;

  /// (P230 §2) GORUNUM MODU — YUKARIDAN VERILIR, burada okunmaz.
  ///
  /// Ilk yazimda bu widget `gorunumModuProvider`i KENDI okuyordu ve
  /// `ProviderScope` gerektirir hale geldi: onu duz `MaterialApp` icinde
  /// cizen 13 mevcut test "No ProviderScope found" ile dustu. Kirilma bir
  /// TASARIM SINYALIYDI — yaprak bir gorsel bilesen kuresel duruma
  /// uzanmamali. Modu ekran okur, izgaraya PARAMETRE olarak gecer.
  final GorunumModu mod;

  final List<HizliErisimKart> kartlar;
  final ValueChanged<HizliErisimKart> onSec;

  @override
  State<HizliErisimIzgarasi> createState() => _HizliErisimIzgarasiState();
}

class _HizliErisimIzgarasiState extends State<HizliErisimIzgarasi> {
  // TITREME KURALI: gruplar STATE'te durur, `build()` icinde URETILMEZ.
  final baslikGrubu = AutoSizeGroup();
  final sayacGrubu = AutoSizeGroup();

  /// (P251 §11) Surukleme suresince ONIZLEME sirasi — diger kartlar "yer
  /// acar". Birakinca kaydedilir, iptal edilirse atilir.
  List<HizliErisimKart>? _onizleme;
  bool _surukleniyor = false;

  @override
  void didUpdateWidget(covariant HizliErisimIzgarasi eski) {
    super.didUpdateWidget(eski);
    // Yeni sira ust katmandan geldi (ya da sayac yenilendi): onizleme
    // artik gereksiz — surukleme suruyorsa dokunulmaz.
    if (!_surukleniyor) _onizleme = null;
  }

  static String _kimlik(HizliErisimKart k) => '${k.id.name}|${k.rota}';

  int _sira(List<HizliErisimKart> l, HizliErisimKart k) =>
      l.indexWhere((x) => _kimlik(x) == _kimlik(k));

  void _kaydet(List<HizliErisimKart> yeni) {
    setState(() => _onizleme = yeni);
    widget.onSiraDegisti?.call(yeni);
  }

  @override
  Widget build(BuildContext context) {
    final kartlar = _onizleme ?? widget.kartlar;
    if (kartlar.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, c) {
        // (P230 §2) BUYUK MOD: 2 sutun, 4 karo. Sekiz karoyu buyutup
        // ekrana sigdirmaya calismak her karoyu yeniden kuculturdu —
        // ayar HICBIR SEY yapmamis olurdu. "Az oge" > "kucuk oge".
        final mod = widget.mod;
        final sutun = mod.izgaraSutun ?? hizliErisimSutun(c.maxWidth);
        final hucre = (c.maxWidth - HomeTokens.gridGap * (sutun - 1)) / sutun;
        final oran = izgaraOrani(context, hizliErisimOran(sutun));
        // Hangi dortlu kalir: KULLANICININ KENDI izgara sirasinin
        // ilk dordu. "Buyuk mod icin ayri liste" kavrami eklemek,
        // kullaniciya IKINCI bir duzenleme ekrani ogretmek olurdu.
        // Gorunen kartlar listenin ONEKI oldugu icin tasima indeksleri
        // tum listede de ayni yeri gosterir.
        final gorunen = kartlar.take(mod.izgaraKaroSiniri ?? kartlar.length).toList();

        Widget kart(HizliErisimKart k, {bool tasinan = false}) => HizliErisimKarti(
              kart: k,
              onTap: () => widget.onSec(k),
              hucreGenisligi: hucre,
              // Tasinan kopya ORTAK gruba girmez: ust katmanda yasayan
              // gecici bir uye, izgaradaki kartlarin puntosunu oynatirdi.
              baslikGrubu: tasinan ? null : baslikGrubu,
              sayacGrubu: tasinan ? null : sayacGrubu,
            );

        return GridView.count(
          crossAxisCount: sutun,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: HomeTokens.gridGap,
          crossAxisSpacing: HomeTokens.gridGap,
          childAspectRatio: oran,
          children: [
            for (final (i, k) in gorunen.indexed)
              if (widget.onSiraDegisti == null)
                kart(k)
              else
                KeyedSubtree(
                  // Kimlikli: sira degisince kart DURUMUYLA tasinir; surukleme
                  // sirasinda tutulan kart yeniden kurulmaz.
                  key: ValueKey('izgara-${_kimlik(k)}'),
                  child: Semantics(
                    customSemanticsActions: {
                      if (i > 0)
                        CustomSemanticsAction(label: l10n.izgaraYukariTasi): () =>
                            _kaydet(izgaradaSiraDegistir(kartlar, i, i - 1)),
                      if (i < gorunen.length - 1)
                        CustomSemanticsAction(label: l10n.izgaraAsagiTasi): () =>
                            _kaydet(izgaradaSiraDegistir(kartlar, i, i + 1)),
                    },
                    child: DragTarget<HizliErisimKart>(
                      // Uzerine gelince diger kartlar YER ACAR (onizleme).
                      onWillAcceptWithDetails: (d) {
                        final l = _onizleme ?? widget.kartlar;
                        final eski = _sira(l, d.data);
                        final yeni = _sira(l, k);
                        if (eski >= 0 && yeni >= 0 && eski != yeni) {
                          setState(() =>
                              _onizleme = izgaradaSiraDegistir(l, eski, yeni));
                        }
                        return true;
                      },
                      onAcceptWithDetails: (_) {
                        _surukleniyor = false;
                        final l = _onizleme;
                        if (l != null) _kaydet(l);
                      },
                      builder: (context, _, _) => LongPressDraggable<HizliErisimKart>(
                        data: k,
                        // Kalkis titresimi (Flutter varsayilani da acik;
                        // acikca yazildi ki kural okunsun).
                        hapticFeedbackOnStart: true,
                        onDragStarted: () => setState(() {
                          _surukleniyor = true;
                          _onizleme = List.of(widget.kartlar);
                        }),
                        // Kart bir hedefin DISINDA birakildi: sira geri alinir.
                        onDraggableCanceled: (_, _) => setState(() {
                          _surukleniyor = false;
                          _onizleme = null;
                        }),
                        feedback: SizedBox(
                          width: hucre,
                          height: hucre / oran,
                          child: Transform.scale(
                            scale: 1.06,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 8,
                              borderRadius:
                                  BorderRadius.circular(HomeTokens.cardRadius),
                              child: kart(k, tasinan: true),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: kart(k)),
                        child: kart(k),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// (P251 §11) Bir karti [eski] yerinden [yeni] yerine tasi (saf).
List<HizliErisimKart> izgaradaSiraDegistir(
  List<HizliErisimKart> kartlar,
  int eski,
  int yeni,
) {
  final l = List.of(kartlar);
  final k = l.removeAt(eski);
  l.insert(yeni.clamp(0, l.length), k);
  return l;
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
