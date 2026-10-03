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

// ======================= (P253 Asama 1) FINANS DEFTERI ======================= #

/// `GET /finans/hareketler` satiri — web `/finans` ve hareket sayfalarinin
/// AYNI ucu. Tutar her zaman POZITIF; yon `giris`/`cikis`.
class FinansHareketi {
  const FinansHareketi({
    required this.id,
    required this.tip,
    required this.yon,
    required this.tutarKurus,
    required this.tarih,
    required this.durum,
    this.kasaAd,
    this.userAd,
    this.personelAd,
    this.unitNo,
    this.belgeNo,
    this.aciklama,
    this.iptalEdildi = false,
  });

  final String id;
  final String tip;
  final String yon;
  final int tutarKurus;
  final DateTime tarih;

  /// `odendi` | `bekliyor` | `onay_bekliyor` | `iptal`.
  final String durum;
  final String? kasaAd;
  final String? userAd;
  final String? personelAd;
  final String? unitNo;
  final String? belgeNo;
  final String? aciklama;
  final bool iptalEdildi;

  bool get giris => yon == 'giris';
  bool get onayBekliyor => durum == 'onay_bekliyor';

  /// (P253 §C-1) Onay diyalogundaki HEDEF: daire · kisi · belge.
  String get hedef => [unitNo, userAd ?? personelAd, belgeNo]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');

  factory FinansHareketi.fromJson(Map<String, dynamic> j) => FinansHareketi(
        id: j['id'] as String,
        tip: (j['tip'] as String?) ?? '',
        yon: (j['yon'] as String?) ?? 'cikis',
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
        tarih: DateTime.tryParse(j['tarih'] as String? ?? '') ?? DateTime(1970),
        durum: (j['durum'] as String?) ?? 'odendi',
        kasaAd: j['kasa_ad'] as String?,
        userAd: j['user_ad'] as String?,
        personelAd: j['personel_ad'] as String?,
        unitNo: j['unit_no'] as String?,
        belgeNo: j['belge_no'] as String?,
        aciklama: j['aciklama'] as String?,
        iptalEdildi: (j['iptal_edildi'] as bool?) ?? false,
      );
}

/// `GET /finans/kasa-bakiyeleri` satiri. BAKIYE SUNUCUDAN — istemci toplamaz.
class KasaBakiyesi {
  const KasaBakiyesi({
    required this.kasaId,
    required this.kod,
    required this.ad,
    required this.bakiyeKurus,
    this.bekleyenCikisKurus = 0,
    this.bankaMi = false,
  });

  final String kasaId;
  final String kod;
  final String ad;
  final int bakiyeKurus;

  /// (P192 §2.2) Onay bekleyen cikis — bakiyeye DAHIL DEGIL.
  final int bekleyenCikisKurus;
  final bool bankaMi;

  factory KasaBakiyesi.fromJson(Map<String, dynamic> j) => KasaBakiyesi(
        kasaId: j['kasa_id'] as String,
        kod: (j['kod'] as String?) ?? '',
        ad: (j['ad'] as String?) ?? '',
        bakiyeKurus: (j['bakiye_kurus'] as num?)?.toInt() ?? 0,
        bekleyenCikisKurus: (j['bekleyen_cikis_kurus'] as num?)?.toInt() ?? 0,
        bankaMi: (j['banka_mi'] as bool?) ?? false,
      );
}

class KasaBakiyeleri {
  const KasaBakiyeleri({
    this.kasalar = const [],
    this.genelToplamKurus = 0,
    this.bekleyenCikisToplamKurus = 0,
  });

  final List<KasaBakiyesi> kasalar;
  final int genelToplamKurus;
  final int bekleyenCikisToplamKurus;

  factory KasaBakiyeleri.fromJson(Map<String, dynamic> j) => KasaBakiyeleri(
        kasalar: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => KasaBakiyesi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        genelToplamKurus: (j['genel_toplam_kurus'] as num?)?.toInt() ?? 0,
        bekleyenCikisToplamKurus:
            (j['bekleyen_cikis_toplam_kurus'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /finans/ozet` — web `/finans` ozet seridinin AYNI alanlari.
class FinansOzeti {
  const FinansOzeti({
    this.borclandirilanAyKurus = 0,
    this.tahsilEdilenAyKurus = 0,
    this.acikBorcKurus = 0,
    this.kasaToplamKurus = 0,
    this.icraAcikDosya = 0,
    this.onayBekleyenAdet = 0,
    this.personelGideriAyKurus = 0,
  });

  final int borclandirilanAyKurus;
  final int tahsilEdilenAyKurus;
  final int acikBorcKurus;
  final int kasaToplamKurus;
  final int icraAcikDosya;
  final int onayBekleyenAdet;
  final int personelGideriAyKurus;

  factory FinansOzeti.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return FinansOzeti(
      borclandirilanAyKurus: n('borclandirilan_ay_kurus'),
      tahsilEdilenAyKurus: n('tahsil_edilen_ay_kurus'),
      acikBorcKurus: n('acik_borc_kurus'),
      kasaToplamKurus: n('kasa_toplam_kurus'),
      icraAcikDosya: n('icra_acik_dosya'),
      onayBekleyenAdet: n('onay_bekleyen_adet'),
      personelGideriAyKurus: n('personel_gideri_ay_kurus'),
    );
  }
}

/// `GET /otomasyon-gunlugu` satiri — otomasyon NE ZAMAN NE YAPTI.
class OtomasyonGunlukSatiri {
  const OtomasyonGunlukSatiri({
    required this.id,
    required this.tur,
    required this.calismaZamani,
    required this.adet,
    required this.tutarKurus,
    this.donem,
  });

  final String id;
  final String tur;
  final DateTime calismaZamani;
  final int adet;
  final int tutarKurus;
  final String? donem;

  factory OtomasyonGunlukSatiri.fromJson(Map<String, dynamic> j) =>
      OtomasyonGunlukSatiri(
        id: j['id'] as String,
        tur: (j['tur'] as String?) ?? '',
        calismaZamani:
            DateTime.tryParse(j['calisma_zamani'] as String? ?? '') ?? DateTime(1970),
        adet: (j['adet'] as num?)?.toInt() ?? 0,
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
        donem: j['donem'] as String?,
      );
}

/// `GET /finans/hatirlatma-gecmisi` — kac hatirlatma gitti, kim okudu.
class HatirlatmaGecmisi {
  const HatirlatmaGecmisi({
    this.gonderilen = 0,
    this.okunan = 0,
    this.satirlar = const [],
  });

  final int gonderilen;
  final int okunan;
  final List<({String? ad, DateTime zaman, bool okundu, String? tutar})> satirlar;

  factory HatirlatmaGecmisi.fromJson(Map<String, dynamic> j) => HatirlatmaGecmisi(
        gonderilen: (j['gonderilen'] as num?)?.toInt() ?? 0,
        okunan: (j['okunan'] as num?)?.toInt() ?? 0,
        satirlar: [
          for (final m in ((j['items'] as List?) ?? const []).whereType<Map>())
            (
              ad: m['ad'] as String?,
              zaman: DateTime.tryParse(m['gonderim_zamani'] as String? ?? '') ??
                  DateTime(1970),
              okundu: (m['okundu'] as bool?) ?? false,
              tutar: m['tutar'] as String?,
            ),
        ],
      );
}

/// Firma (gider/gelir satirinin karsi tarafi) — `GET /firmalar`.
class Firma {
  const Firma({required this.id, required this.ad});

  final String id;
  final String ad;

  factory Firma.fromJson(Map<String, dynamic> j) =>
      Firma(id: j['id'] as String, ad: (j['ad'] as String?) ?? '');
}
