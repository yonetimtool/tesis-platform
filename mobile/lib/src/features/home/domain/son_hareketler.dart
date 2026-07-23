/// "Son Hareketler" birlesik akisi — SAF fonksiyonlar (widget/provider yok).
/// Backend'de birlesik aktivite ucu YOK (MISSING-BACKEND); akis, sakinin
/// zaten erisebildigi kaynaklardan ISTEMCIDE birlestirilir: kargo +
/// ziyaretci + basarili aidat odemeleri. KVKK: yalniz kendi verisi (sunucu
/// suzer); baska daire/kisi sizmaz.
library;

import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../dues/domain/dues_models.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../visitors/domain/visitor_models.dart';

/// Akistaki tek satirin turu — ikon/renk eslemesi sunumda.
enum HareketTip { kargoKayit, kargoTeslim, ziyaretci, aidatOdeme }

/// Birlesik akisin tek satiri.
class Hareket {
  const Hareket({
    required this.tip,
    required this.baslik,
    required this.altBaslik,
    required this.zaman,
  });

  final HareketTip tip;
  final String baslik;
  final String altBaslik;
  final DateTime zaman;
}

/// Satir zaman etiketi — [now] DISARIDAN (deterministik test; saat-flake yok).
/// Ayni gun "HH:mm", dun "Dün", daha eski "dd.MM".
String hareketZamanEtiketi(DateTime t, DateTime now) {
  bool ayniGun(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (ayniGun(t, now)) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
  if (ayniGun(t, now.subtract(const Duration(days: 1)))) return 'Dün';
  return '${t.day.toString().padLeft(2, '0')}.'
      '${t.month.toString().padLeft(2, '0')}';
}

/// Sakin akisi: kaynaklari Hareket'e esler, zamana gore DESC siralar, en
/// yeni [limit] taneyi doner. Kargo teslimlerinde teslim zamani esastir;
/// yalniz 'basarili' aidat odemeleri akisa girer.
List<Hareket> residentHareketleri({
  required List<Kargo> kargolar,
  required List<Visitor> ziyaretciler,
  required List<MyDuesUnit> duesUnits,
  int limit = 5,
}) {
  final hareketler = <Hareket>[
    for (final k in kargolar)
      if (k.durum == KargoDurum.teslimAlindi)
        Hareket(
          tip: HareketTip.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altBaslik: '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.teslimZamani ?? k.createdAt,
        )
      else
        Hareket(
          tip: HareketTip.kargoKayit,
          baslik: 'Kargo Kaydedildi',
          altBaslik: '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.createdAt,
        ),
    for (final z in ziyaretciler)
      Hareket(
        tip: HareketTip.ziyaretci,
        baslik: 'Ziyaretçi Girişi',
        altBaslik:
            '${z.ziyaretciAd}${z.unitNo != null ? ' - Daire ${z.unitNo}' : ''}',
        zaman: z.createdAt,
      ),
    for (final u in duesUnits)
      for (final p in u.payments)
        if (p.durum == 'basarili')
          Hareket(
            tip: HareketTip.aidatOdeme,
            baslik: 'Aidat Ödemesi',
            altBaslik:
                '₺${formatKurusAsTl(p.tutarKurus)}${p.donem != null ? ' - ${p.donem}' : ''}',
            zaman: p.odemeZamani,
          ),
  ]..sort((a, b) => b.zaman.compareTo(a.zaman));

  return hareketler.take(limit).toList();
}
