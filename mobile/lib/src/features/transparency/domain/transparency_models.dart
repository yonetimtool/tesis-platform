/// Şeffaflık Panosu domain modelleri — `GET /transparency`, `GET /transparency/{ay}`.
/// TÜM alanlar AGREGAT: ad/daire-etiketi/bireysel-tutar İÇERMEZ. Para integer kuruş.
library;

class TransparencyKategori {
  const TransparencyKategori({
    required this.ad,
    required this.toplamKurus,
    required this.yuzde,
  });

  final String ad; // kategori adı (kişisel veri DEĞİL) — "Diğer" toplu kalan
  final int toplamKurus;
  final int yuzde; // toplam gider içindeki pay (0-100)

  factory TransparencyKategori.fromJson(Map<String, dynamic> j) =>
      TransparencyKategori(
        ad: j['ad'] as String? ?? '',
        toplamKurus: (j['toplam_kurus'] as num?)?.toInt() ?? 0,
        yuzde: (j['yuzde'] as num?)?.toInt() ?? 0,
      );
}

class TransparencyAidat {
  const TransparencyAidat({
    required this.tahakkukKurus,
    required this.tahsilatKurus,
    required this.toplamDaire,
    required this.odeyenDaire,
    required this.gecikenDaireSayisi,
    this.tutarOraniYuzde,
    this.daireOraniYuzde,
  });

  final int tahakkukKurus;
  final int tahsilatKurus;
  final int? tutarOraniYuzde; // tutar-bazlı (null = tanımsız)
  final int toplamDaire;
  final int odeyenDaire;
  final int? daireOraniYuzde; // adet(daire)-bazlı (null = tanımsız)
  final int gecikenDaireSayisi; // SAYI ONLY — hangi daire asla

  factory TransparencyAidat.fromJson(Map<String, dynamic> j) => TransparencyAidat(
        tahakkukKurus: (j['tahakkuk_kurus'] as num?)?.toInt() ?? 0,
        tahsilatKurus: (j['tahsilat_kurus'] as num?)?.toInt() ?? 0,
        tutarOraniYuzde: (j['tutar_orani_yuzde'] as num?)?.toInt(),
        toplamDaire: (j['toplam_daire'] as num?)?.toInt() ?? 0,
        odeyenDaire: (j['odeyen_daire'] as num?)?.toInt() ?? 0,
        daireOraniYuzde: (j['daire_orani_yuzde'] as num?)?.toInt(),
        gecikenDaireSayisi: (j['geciken_daire_sayisi'] as num?)?.toInt() ?? 0,
      );
}

class TransparencyBoard {
  const TransparencyBoard({
    required this.ay,
    required this.yayinlandi,
    required this.toplamGelirKurus,
    required this.toplamGiderKurus,
    required this.netKurus,
    required this.giderDagilimi,
    required this.aidat,
    this.oncekiAyNetKurus,
  });

  final String ay;
  final bool yayinlandi;
  final int toplamGelirKurus;
  final int toplamGiderKurus;
  final int netKurus;
  final List<TransparencyKategori> giderDagilimi;
  final TransparencyAidat aidat;
  final int? oncekiAyNetKurus;

  factory TransparencyBoard.fromJson(Map<String, dynamic> j) => TransparencyBoard(
        ay: j['ay'] as String? ?? '',
        yayinlandi: j['yayinlandi'] as bool? ?? false,
        toplamGelirKurus: (j['toplam_gelir_kurus'] as num?)?.toInt() ?? 0,
        toplamGiderKurus: (j['toplam_gider_kurus'] as num?)?.toInt() ?? 0,
        netKurus: (j['net_kurus'] as num?)?.toInt() ?? 0,
        giderDagilimi: ((j['gider_dagilimi'] as List<dynamic>?) ?? const [])
            .map((e) => TransparencyKategori.fromJson(e as Map<String, dynamic>))
            .toList(),
        aidat: TransparencyAidat.fromJson(
            (j['aidat'] as Map<String, dynamic>?) ?? const {}),
        oncekiAyNetKurus: (j['onceki_ay_net_kurus'] as num?)?.toInt(),
      );
}

class TransparencyAyOzet {
  const TransparencyAyOzet({
    required this.ay,
    required this.yayinlandi,
    this.netKurus,
  });

  final String ay;
  final bool yayinlandi;
  final int? netKurus;

  factory TransparencyAyOzet.fromJson(Map<String, dynamic> j) => TransparencyAyOzet(
        ay: j['ay'] as String? ?? '',
        yayinlandi: j['yayinlandi'] as bool? ?? false,
        netKurus: (j['net_kurus'] as num?)?.toInt(),
      );
}
