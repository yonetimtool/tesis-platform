/// Ana ekranin YUKLENIYOR / HATA gorunumleri.
///
/// Kural: hicbir kart UYDURMA sayi gostermez. Veri gelene kadar sayac
/// yerinde notr bir iskelet cubugu durur; uc hata verirse bolum bos beyaz
/// kalmaz — "Yüklenemedi" + "Yeniden dene" cizilir. Olculer referans
/// tipografiyle ayni yuksekliktedir; duzen kaymaz.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import 'home_card.dart';
import 'section_header.dart';

/// Metin yuksekliginde notr gri cubuk — sayac/deger yer tutucusu.
class HomeIskeletCubugu extends StatelessWidget {
  const HomeIskeletCubugu({
    super.key,
    this.genislik = 44,
    this.yukseklik = 11,
  });

  final double genislik;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Container(
      width: genislik,
      height: yukseklik,
      decoration: BoxDecoration(
        color: s.placeholder,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Hizli erisim kartinin sayac satiri yerine gecen iskelet — [HomeText
/// .cardCounter] satiriyla AYNI yuksekligi kaplar (13px + satir bosluğu),
/// boylece veri gelince kart zıplamaz.
class HomeSayacIskeleti extends StatelessWidget {
  const HomeSayacIskeleti({super.key, this.genislik = 40});

  final double genislik;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 16,
        child: Center(
          child: HomeIskeletCubugu(genislik: genislik, yukseklik: 10),
        ),
      );
}

/// Bolum (Son Hareketler / Ödeme ve Aidat Durumu / Duyurular) yerine gecen
/// yukleme karti: bolum basligi + kart icinde [satir] adet iskelet cizgisi.
class HomeBolumIskeleti extends StatelessWidget {
  const HomeBolumIskeleti({
    super.key,
    required this.baslik,
    this.satir = 3,
  });

  final String baslik;
  final int satir;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: baslik),
        HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              for (var i = 0; i < satir; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: HomeTokens.rowIconBox,
                      height: HomeTokens.rowIconBox,
                      decoration: BoxDecoration(
                        color: s.placeholder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeIskeletCubugu(genislik: 140, yukseklik: 12),
                          SizedBox(height: 7),
                          HomeIskeletCubugu(genislik: 90, yukseklik: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bolum yuklenemedigi zaman cizilen kart: gri aciklama + "Yeniden dene".
/// Referansta yeri olmayan bir bolum EKLEMEZ — hatali bolumun YERINE gecer.
class HomeBolumHatasi extends StatelessWidget {
  const HomeBolumHatasi({
    super.key,
    required this.baslik,
    required this.onYenile,
    this.mesaj = 'Yüklenemedi',
  });

  final String baslik;
  final String mesaj;
  final VoidCallback onYenile;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: baslik),
        HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 20, color: s.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mesaj,
                  style: HomeText.cardCounter.copyWith(color: s.muted),
                ),
              ),
              TextButton(
                key: const Key('bolum-yeniden-dene'),
                onPressed: onYenile,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Yeniden dene', style: HomeText.link),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
