/// (P206 §4) MOBIL FINANS MODELLERI — tahsilat, gider, borclular.
library;

/// Kasa/banka hesabi — tahsilat ve giderin ZORUNLU alani.
class Kasa {
  const Kasa({required this.id, required this.ad, this.bankaMi = false});

  final String id;
  final String ad;
  final bool bankaMi;

  factory Kasa.fromJson(Map<String, dynamic> j) => Kasa(
        id: j['id'] as String,
        ad: (j['ad'] as String?) ?? '',
        bankaMi: (j['banka_mi'] as bool?) ?? false,
      );
}

/// Gider turu (gelir/gider tanimi).
class GiderTuru {
  const GiderTuru({required this.id, required this.ad});

  final String id;
  final String ad;

  factory GiderTuru.fromJson(Map<String, dynamic> j) => GiderTuru(
        id: j['id'] as String,
        ad: (j['ad'] as String?) ?? '',
      );
}

/// Borclu satiri — yaslandirmadan turer (P192 TEK KAYNAK).
class Borclu {
  const Borclu({
    required this.unitId,
    required this.unitNo,
    required this.kalanKurus,
    required this.kova,
    required this.enEskiGun,
    this.userId,
    this.ad,
  });

  final String unitId;
  final String unitNo;
  final int kalanKurus;

  /// Yaslandirma kovasi (`0-30`, `31-60`, ...).
  final String kova;
  final int enEskiGun;
  final String? userId;
  final String? ad;

  factory Borclu.fromJson(Map<String, dynamic> j, String kova) => Borclu(
        unitId: j['unit_id'] as String,
        unitNo: (j['unit_no'] as String?) ?? '',
        kalanKurus: (j['kalan_kurus'] as int?) ?? 0,
        kova: kova,
        enEskiGun: (j['en_eski_gun'] as int?) ?? 0,
        userId: j['borclu_user_id'] as String?,
        ad: j['borclu_ad'] as String?,
      );
}

/// Yaslandirma ozeti — kova basina daire sayisi ve tutar.
class YaslandirmaKovasi {
  const YaslandirmaKovasi({
    required this.kova,
    required this.daire,
    required this.kalanKurus,
    this.borclular = const [],
  });

  final String kova;
  final int daire;
  final int kalanKurus;
  final List<Borclu> borclular;

  factory YaslandirmaKovasi.fromJson(Map<String, dynamic> j) {
    final kova = (j['kova'] as String?) ?? '';
    return YaslandirmaKovasi(
      kova: kova,
      daire: (j['daire'] as int?) ?? 0,
      kalanKurus: (j['kalan_kurus'] as int?) ?? 0,
      borclular: ((j['daireler'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Borclu.fromJson(Map<String, dynamic>.from(m), kova))
          .toList(),
    );
  }
}

class Yaslandirma {
  const Yaslandirma({
    this.kovalar = const [],
    this.toplamKalanKurus = 0,
    this.toplamDaire = 0,
  });

  final List<YaslandirmaKovasi> kovalar;
  final int toplamKalanKurus;
  final int toplamDaire;

  List<Borclu> get tumBorclular =>
      kovalar.expand((k) => k.borclular).toList()
        ..sort((a, b) => b.kalanKurus.compareTo(a.kalanKurus));

  factory Yaslandirma.fromJson(Map<String, dynamic> j) => Yaslandirma(
        kovalar: ((j['kovalar'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => YaslandirmaKovasi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        toplamKalanKurus: (j['toplam_kalan_kurus'] as int?) ?? 0,
        toplamDaire: (j['toplam_daire'] as int?) ?? 0,
      );
}

/// (P192 §5.2) Tahsilat gostergesi — TEK KAYNAK `defter.tahsilat_toplami`.
class TahsilatGostergesi {
  const TahsilatGostergesi({
    required this.donem,
    required this.tahakkukKurus,
    required this.tahsilatKurus,
    this.oranYuzde,
  });

  final String donem;
  final int tahakkukKurus;
  final int tahsilatKurus;
  final int? oranYuzde;

  factory TahsilatGostergesi.fromJson(Map<String, dynamic> j) =>
      TahsilatGostergesi(
        donem: (j['donem'] as String?) ?? '',
        tahakkukKurus: (j['tahakkuk_kurus'] as int?) ?? 0,
        tahsilatKurus: (j['tahsilat_kurus'] as int?) ?? 0,
        oranYuzde: j['oran_yuzde'] as int?,
      );
}
