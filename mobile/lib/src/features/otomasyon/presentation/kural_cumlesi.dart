/// (P250 §9) Kuralların DÜZ CÜMLESİ — web `lib/otomasyon-cumle.ts` ikizi.
///
/// Teknik terim (tahakkuk, kademe, periyot, dağıtım) cümleye girmez.
library;

import '../../../core/i18n/l10n.dart';
import '../data/otomasyon_api.dart';

String siklikMetni(AppLocalizations l10n, String periyot) => switch (periyot) {
  'uc_aylik' => l10n.otoKuralSiklikUcAylik,
  'alti_aylik' => l10n.otoKuralSiklikAltiAylik,
  'yillik' => l10n.otoKuralSiklikYillik,
  _ => l10n.otoKuralSiklikAylik,
};

String paylasimSecenegi(AppLocalizations l10n, String dagitim) =>
    switch (dagitim) {
      'esit' => l10n.otoSihirbazPaylasimEsit,
      'arsa_payi' => l10n.otoSihirbazPaylasimArsa,
      'metrekare' => l10n.otoSihirbazPaylasimMetrekare,
      _ => l10n.otoSihirbazPaylasimDaire,
    };

String planCumlesi(
  AppLocalizations l10n,
  String dil, {
  required String ad,
  required String dagitim,
  required int? tutarKurus,
  required int? toplamTutarKurus,
  required int gun,
  required int vadeGun,
}) {
  if (dagitim == 'daire_basina') {
    return l10n.otoKuralPlanCumle(
      '$gun', tlIsaretli(tutarKurus ?? 0, dil), ad, '$vadeGun');
  }
  final paylasim = switch (dagitim) {
    'arsa_payi' => l10n.otoKuralPaylasimArsa,
    'metrekare' => l10n.otoKuralPaylasimMetrekare,
    _ => l10n.otoKuralPaylasimEsit,
  };
  return l10n.otoKuralPlanCumleToplam(
    '$gun', tlIsaretli(toplamTutarKurus ?? 0, dil), ad, paylasim, '$vadeGun');
}

String giderCumlesi(
  AppLocalizations l10n,
  String dil, {
  required String ad,
  required int tutarKurus,
  required String periyot,
  required DateTime sonrakiTarih,
  required bool otomatikOnay,
}) => l10n.otoKuralGiderCumle(
  siklikMetni(l10n, periyot),
  ad,
  tlIsaretli(tutarKurus, dil),
  otomatikOnay ? l10n.otoKuralGiderOtomatik : l10n.otoKuralGiderOnayBekler,
  tarihBicimi(sonrakiTarih, dil),
);

String gecikmeCumlesi(AppLocalizations l10n, GecikmeKurali g) =>
    !g.uygula || g.yuzde <= 0
        ? l10n.otoKuralGecikmeKapali
        : l10n.otoKuralGecikmeCumle(
            g.yuzde == g.yuzde.roundToDouble()
                ? '${g.yuzde.toInt()}'
                : '${g.yuzde}',
          );

String sonCalismaCumlesi(AppLocalizations l10n, String dil, SonCalisma? s) {
  if (s == null) return l10n.otoKuralSonYok;
  final z = tarihSaatBicimi(s.zaman, dil);
  if (s.durum == 'ertelendi') return l10n.otoKuralSonErtelendi(z);
  final tutar = tlIsaretli(s.tutarKurus, dil);
  return switch (s.tur) {
    'aidat_tahakkuk' => l10n.otoKuralSonPlan(z, '${s.adet}', tutar),
    'duzenli_gider' => l10n.otoKuralSonGider(z),
    'borc_hatirlatma' => l10n.otoKuralSonHatirlatma(z, '${s.adet}'),
    'gecikme_faizi' => l10n.otoKuralSonGecikme(z, '${s.adet}', tutar),
    _ => l10n.otoKuralSonYok,
  };
}

/// Bugünden itibaren ayın [gun]üne denk gelen ilk tarih.
DateTime ilkAylikTarih(int gun, DateTime bugun) =>
    bugun.day <= gun
        ? DateTime(bugun.year, bugun.month, gun)
        : DateTime(bugun.year, bugun.month + 1, gun);
