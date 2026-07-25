import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'home_states.dart';

/// Referans "Hızlı Özet" kutusu (yonetici.jpeg): ortada tint ikon konteyneri,
/// altinda 20 bold deger, 13 semibold etiket ve 12 gri alt-etiket.
///
/// Kutu DOKUNULABILIR: ozet degerinden ilgili ekrana kisa yol ([onTap]).
/// Rotasi olmayan kutuda da dokunma cagrilir — hedefi cagiran katman belirler
/// (ekranda "yakında" bilgilendirmesi).
///
/// [degerGrubu] ayni bolumdeki kutularin degerini TEK TIP boyutta cizer
/// ("512" ile "₺248.750" ayni buyuklukte; kesme yok).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.kutu,
    this.onTap,
    this.hucreGenisligi,
    this.degerGrubu,
    this.etiketGrubu,
  });

  final OzetKutusu kutu;
  final VoidCallback? onTap;
  final double? hucreGenisligi;
  final AutoSizeGroup? degerGrubu;
  final AutoSizeGroup? etiketGrubu;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final kutuBoyut = hucreGenisligi == null
        ? HomeTokens.iconBox
        : (hucreGenisligi! * 0.40).clamp(32.0, HomeTokens.iconBox);
    // Dar hucrede (4 sutunlu izgara) etiket TEK satirdir — referans gorselde
    // de tek satir; iki satir yuksekligi tasirirdi.
    final dar = hucreGenisligi != null && hucreGenisligi! < 120;

    return HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HomeIconBox(
            icon: kutu.ikon,
            accent: kutu.accent,
            size: kutuBoyut,
            iconSize: (kutuBoyut * 0.55).clamp(17.0, HomeTokens.iconSize),
          ),
          const SizedBox(height: 6),
          // Deger YOKKEN (gercek uc henuz yuklenmedi) iskelet — referans
          // yerlesimi korunur, uydurma sayi gosterilmez.
          if (kutu.deger == null)
            const SizedBox(
              height: 22,
              child: Center(child: HomeIskeletCubugu(genislik: 52)),
            )
          else
            AutoSizeText(
              kutu.deger!,
              group: degerGrubu,
              maxLines: 1,
              minFontSize: 11,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: HomeText.statValue.copyWith(color: s.heading),
            ),
          const SizedBox(height: 2),
          AutoSizeText(
            kutu.etiket,
            group: etiketGrubu,
            maxLines: dar ? 1 : 2,
            minFontSize: 8,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: HomeText.statLabel.copyWith(color: s.body),
          ),
          const SizedBox(height: 1),
          AutoSizeText(
            kutu.altEtiket,
            group: etiketGrubu,
            maxLines: 1,
            minFontSize: 8,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: HomeText.rowSub.copyWith(color: s.muted),
          ),
        ],
      ),
    );
  }
}

/// "Hızlı Özet" bolumu — 4'lu istatistik izgarasi (dar ekranda 2'li).
class HizliOzetIzgarasi extends StatelessWidget {
  const HizliOzetIzgarasi({super.key, required this.kutular, this.onSec});

  final List<OzetKutusu> kutular;

  /// Kutuya dokunuldu (rotasi olmayan kutuda da cagrilir).
  final ValueChanged<OzetKutusu>? onSec;

  @override
  Widget build(BuildContext context) {
    if (kutular.isEmpty) return const SizedBox.shrink();
    final degerGrubu = AutoSizeGroup();
    final etiketGrubu = AutoSizeGroup();

    return LayoutBuilder(builder: (context, c) {
      // Esik hizli erisim izgarasiyla AYNI (bkz. hizliErisimSutun).
      final sutun = c.maxWidth < 300 ? 2 : 4;
      final hucre = (c.maxWidth - HomeTokens.gridGap * (sutun - 1)) / sutun;
      return GridView.count(
        crossAxisCount: sutun,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: HomeTokens.gridGap,
        crossAxisSpacing: HomeTokens.gridGap,
        childAspectRatio: sutun == 4 ? 0.66 : 1.1,
        children: [
          for (final k in kutular)
            StatTile(
              kutu: k,
              onTap: onSec == null ? null : () => onSec!(k),
              hucreGenisligi: hucre,
              degerGrubu: degerGrubu,
              etiketGrubu: etiketGrubu,
            ),
        ],
      );
    });
  }
}
