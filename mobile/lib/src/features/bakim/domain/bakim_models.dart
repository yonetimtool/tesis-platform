/// (P241 §1) Periyodik bakim modelleri.
library;

class BakimEkipmani {
  const BakimEkipmani({
    required this.id,
    required this.ad,
    required this.tur,
    required this.periyot,
    required this.sonrakiBakim,
    required this.durum,
    required this.kalanGun,
    required this.yasal,
    this.blokAd,
    this.alan,
    this.sonBakim,
    this.firmaAd,
    this.sorumluAd,
    this.sorumluTelefon,
    this.periyotGun,
  });

  final String id;
  final String ad;
  final String tur;
  final String periyot;
  final int? periyotGun;
  final String? sonBakim;
  final String sonrakiBakim;

  /// SUNUCUDAN TURETILMIS: `gecikti` | `bugun` | `yaklasti` | `planli`.
  ///
  /// Istemcide hesaplanmiyor — cihaz saati kaymis bir telefonda
  /// "gecikmis" bir yasal kontrol "planli" gorunurdu.
  final String durum;

  /// Negatif = gecikme gunu. Arayuz RENGIN YANINDA bu sayiyi yazar.
  final int kalanGun;
  final bool yasal;
  final String? blokAd;
  final String? alan;
  final String? firmaAd;
  final String? sorumluAd;
  final String? sorumluTelefon;

  factory BakimEkipmani.fromJson(Map<String, dynamic> j) => BakimEkipmani(
        id: j['id'] as String,
        ad: j['ad'] as String? ?? '',
        tur: j['tur'] as String? ?? '',
        periyot: j['periyot'] as String? ?? 'yillik',
        periyotGun: (j['periyot_gun'] as num?)?.toInt(),
        sonBakim: j['son_bakim'] as String?,
        sonrakiBakim: j['sonraki_bakim'] as String? ?? '',
        durum: j['durum'] as String? ?? 'planli',
        kalanGun: (j['kalan_gun'] as num?)?.toInt() ?? 0,
        yasal: j['yasal'] as bool? ?? false,
        blokAd: j['blok_ad'] as String?,
        alan: j['alan'] as String?,
        firmaAd: j['firma_ad'] as String?,
        sorumluAd: j['sorumlu_ad'] as String?,
        sorumluTelefon: j['sorumlu_telefon'] as String?,
      );
}

class BakimKaydi {
  const BakimKaydi({
    required this.id,
    required this.ekipmanId,
    required this.tarih,
    this.ekipmanAd,
    this.yapanAd,
    this.islem,
    this.tutarKurus,
  });

  final String id;
  final String ekipmanId;
  final String tarih;
  final String? ekipmanAd;
  final String? yapanAd;
  final String? islem;
  final int? tutarKurus;

  factory BakimKaydi.fromJson(Map<String, dynamic> j) => BakimKaydi(
        id: j['id'] as String,
        ekipmanId: j['ekipman_id'] as String? ?? '',
        tarih: j['tarih'] as String? ?? '',
        ekipmanAd: j['ekipman_ad'] as String?,
        yapanAd: j['yapan_ad'] as String? ?? j['firma_ad'] as String?,
        islem: j['islem'] as String?,
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt(),
      );
}

/// Yeni bakim kaydi taslagi.
class BakimKaydiTaslak {
  const BakimKaydiTaslak({
    required this.tarih,
    this.yapanAd,
    this.islem,
    this.tutarKurus,
    this.gidereYaz = true,
  });

  final String tarih;
  final String? yapanAd;
  final String? islem;
  final int? tutarKurus;

  /// Tutar deftere ONAY BEKLEYEN gider olarak dussun mu (P192).
  final bool gidereYaz;

  Map<String, dynamic> toJson() => {
        'tarih': tarih,
        if (yapanAd != null && yapanAd!.isNotEmpty) 'yapan_ad': yapanAd,
        if (islem != null && islem!.isNotEmpty) 'islem': islem,
        if (tutarKurus != null) 'tutar_kurus': tutarKurus,
        'gidere_yaz': gidereYaz,
      };
}
