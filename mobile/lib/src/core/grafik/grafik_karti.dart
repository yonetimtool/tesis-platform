import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

/// (P223 §4) MOBIL GRAFIK KARTI — cubuk / yatay cubuk.
///
/// =========================================================================
/// NEDEN KUTUPHANE EKLENMEDI
/// =========================================================================
/// Mobilde grafik kutuphanesi YOKTU. Web'de recharts var ama ayni secimi
/// mobile tasimak mumkun degil; iki yuzey zaten ayri teknoloji. Bir
/// Flutter grafik paketi eklemek ise UC ekran icin kalici bir bagimlilik,
/// surum yukseltme yuku ve APK boyutu demekti.
///
/// Cizilen sey basit: oransal cubuklar. `LayoutBuilder` + `Container`
/// ile yapilir; `CustomPainter` bile gerekmez. Ihtiyac cizgi/pasta
/// grafige donerse karar YENIDEN verilir — o zaman kutuphane haklidir.
///
/// =========================================================================
/// WEB'LE AYNI UC KURAL
/// =========================================================================
///  1. RENK TEK BASINA ANLAM TASIMAZ: her cubugun YANINDA adi ve SAYISAL
///     degeri yazar. Renk korlugunde grafik yalnizca bir suslemedir,
///     bilgi satirdadir.
///  2. VERI YOKSA GRAFIK CIZILMEZ: bos bir eksen "sifir" demek yerine
///     bozuk gorunur; yerine acik bir "veri yok" satiri konur.
///  3. RENKLER TEMADAN: `colorScheme` uzerinden alinir, boylece KARANLIK
///     TEMADA da okunur (sabit renk kodlari koyu zeminde kaybolurdu).
class GrafikDilimi {
  const GrafikDilimi({
    required this.ad,
    required this.deger,
    this.vurgulu = false,
    this.ikon,
  });

  final String ad;
  final double deger;

  /// Bu dilim one cikarilsin mi (orn. gider kalemleri).
  final bool vurgulu;

  /// Satir basi ikonu — RENGE EK bir ayirt edici.
  ///
  /// Gelir/gider ayrimini yalnizca renkle anlatmak renk korlugunde
  /// kaybolurdu; ikon o ayrimi renkten BAGIMSIZ tasir.
  final IconData? ikon;
}

class GrafikKarti extends StatelessWidget {
  const GrafikKarti({
    super.key,
    required this.baslik,
    required this.dilimler,
    required this.bicimle,
    this.bosMetin,
  });

  final String baslik;
  final List<GrafikDilimi> dilimler;

  /// Degeri metne cevirir (para/yuzde). Grafik SUS, sayi BILGIDIR.
  final String Function(double) bicimle;

  /// Veri yokken yazilacak cumle; verilmezse ortak metin kullanilir.
  final String? bosMetin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: tema.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (dilimler.isEmpty)
              Text(
                bosMetin ?? l10n.grafikVeriYok,
                key: const Key('grafik-veri-yok'),
                style: tema.textTheme.bodySmall,
              )
            else
              ..._cubuklar(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _cubuklar(BuildContext context) {
    final tema = Theme.of(context);
    // EN BUYUK DEGER OLCEKTIR. Hepsi sifirsa bolume girmeyiz (NaN cubuk
    // cizilmez); o durumda tum cubuklar bos gorunur ve sayilar 0 yazar.
    final enBuyuk = dilimler
        .map((d) => d.deger.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    return [
      for (final d in dilimler) ...[
        Row(
          children: [
            if (d.ikon != null) ...[
              Icon(d.ikon, size: 16),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                d.ad,
                style: tema.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // SAYI HER ZAMAN YAZILIR — grafik olmasa da bilgi tamdir.
            // `FittedBox`: dar ekranda (320 dp) uzun kategori adi +
            // 7 haneli tutar satiri tasiriyordu; etiket ELLIPSIS,
            // tutar KUCULUR (depodaki `_AmountCard` ile ayni cozum).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  bicimle(d.deger),
                  style: tema.textTheme.bodySmall?.copyWith(
                    fontWeight: d.vurgulu ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, kisit) {
            final oran = enBuyuk <= 0 ? 0.0 : (d.deger.abs() / enBuyuk);
            return Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: kisit.maxWidth * oran,
                  decoration: BoxDecoration(
                    color: d.vurgulu
                        ? tema.colorScheme.primary
                        : tema.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
