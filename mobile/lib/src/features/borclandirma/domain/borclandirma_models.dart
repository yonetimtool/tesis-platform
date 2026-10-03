/// (P253 Asama 2) BORCLANDIRMA — yonetici mobil modelleri.
///
/// Sozlesme: `contracts/openapi.yaml` DuesAssessment, UnitDuesStatus,
/// TopluBorcIstek / TopluBorcOnizleme / DuesAssessmentResult,
/// GecikmeFaizOnizleme. Web `finans/borclandirmalar` ile AYNI govdeler.
library;

/// Tahakkuk (borc kalemi) — `DuesAssessmentOut`.
class Tahakkuk {
  const Tahakkuk({
    required this.id,
    required this.unitId,
    required this.donem,
    required this.tutarKurus,
    this.sonOdeme,
    this.aciklama,
    this.tanimAd,
    this.hedefAd,
    this.kalemTipi = 'aidat',
    this.gecikmeKurus = 0,
    this.tersKayitId,
    this.iptalEdildi = false,
  });

  final String id;
  final String unitId;
  final String donem;
  final int tutarKurus;
  final DateTime? sonOdeme;
  final String? aciklama;
  final String? tanimAd;
  final String? hedefAd;
  final String kalemTipi;
  final int gecikmeKurus;

  /// Doluysa bu satirin KENDISI bir duzeltmedir (ters kayit).
  final String? tersKayitId;

  /// Bu tahakkuk ters kayitla duzeltildi mi.
  final bool iptalEdildi;

  /// Ters kayit yapilabilir mi: duzeltme satiri ya da zaten duzeltilmis
  /// satir ikinci kez ters kayitlanamaz (sunucu da reddeder).
  bool get tersKayitlanabilir => tersKayitId == null && !iptalEdildi;

  factory Tahakkuk.fromJson(Map<String, dynamic> j) => Tahakkuk(
        id: j['id'] as String,
        unitId: (j['unit_id'] as String?) ?? '',
        donem: (j['donem'] as String?) ?? '',
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
        sonOdeme: DateTime.tryParse((j['son_odeme_tarihi'] as String?) ?? ''),
        aciklama: j['aciklama'] as String?,
        tanimAd: j['gelir_gider_tanim_ad'] as String?,
        hedefAd: j['hedef_ad'] as String?,
        kalemTipi: (j['kalem_tipi'] as String?) ?? 'aidat',
        gecikmeKurus: (j['gecikme_kurus'] as num?)?.toInt() ?? 0,
        tersKayitId: j['ters_kayit_id'] as String?,
        iptalEdildi: (j['iptal_edildi'] as bool?) ?? false,
      );
}

/// Daire odemesi — `DuesPaymentOut` (yalniz gosterilen alanlar).
class DaireOdemesi {
  const DaireOdemesi({
    required this.id,
    required this.tutarKurus,
    required this.zaman,
    required this.yontem,
    this.donem,
  });

  final String id;
  final int tutarKurus;
  final DateTime zaman;
  final String yontem;
  final String? donem;

  factory DaireOdemesi.fromJson(Map<String, dynamic> j) => DaireOdemesi(
        id: j['id'] as String,
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
        zaman: DateTime.tryParse((j['odeme_zamani'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        yontem: (j['yontem'] as String?) ?? '',
        donem: j['donem'] as String?,
      );
}

/// `GET /units/{id}/dues` — daire borc durumu.
class DaireBorcu {
  const DaireBorcu({
    required this.unitId,
    required this.no,
    required this.toplamTahakkukKurus,
    required this.toplamOdenenKurus,
    required this.bakiyeKurus,
    required this.tahakkuklar,
    required this.odemeler,
  });

  final String unitId;
  final String no;
  final int toplamTahakkukKurus;
  final int toplamOdenenKurus;
  final int bakiyeKurus;
  final List<Tahakkuk> tahakkuklar;
  final List<DaireOdemesi> odemeler;

  factory DaireBorcu.fromJson(Map<String, dynamic> j) => DaireBorcu(
        unitId: (j['unit_id'] as String?) ?? '',
        no: (j['no'] as String?) ?? '',
        toplamTahakkukKurus: (j['toplam_tahakkuk_kurus'] as num?)?.toInt() ?? 0,
        toplamOdenenKurus: (j['toplam_odenen_kurus'] as num?)?.toInt() ?? 0,
        bakiyeKurus: (j['bakiye_kurus'] as num?)?.toInt() ?? 0,
        tahakkuklar: [
          for (final m in (j['assessments'] as List?) ?? const [])
            if (m is Map) Tahakkuk.fromJson(Map<String, dynamic>.from(m)),
        ],
        odemeler: [
          for (final m in (j['payments'] as List?) ?? const [])
            if (m is Map) DaireOdemesi.fromJson(Map<String, dynamic>.from(m)),
        ],
      );
}

/// Secicilerde kullanilan kisa daire satiri (`GET /units`).
class DaireKisa {
  const DaireKisa({required this.id, required this.no, this.blok});

  final String id;
  final String no;
  final String? blok;

  factory DaireKisa.fromJson(Map<String, dynamic> j) => DaireKisa(
        id: j['id'] as String,
        no: (j['no'] as String?) ?? '',
        blok: j['blok'] as String?,
      );
}

/// Borclandirma turu (gelir-gider tanimi; GELIR olanlar borclandirilamaz).
class BorcTuru {
  const BorcTuru({required this.id, required this.ad});

  final String id;
  final String ad;
}

/// Toplu dagitim yontemi — sunucu `TopluBorcIstek.dagitim`.
const dagitimlar = ['daire_basina', 'esit', 'arsa_payi', 'metrekare'];

/// Kalem tipi — sunucu `TopluBorcIstek.kalem_tipi`. `faiz` YOK: faiz elle
/// yazilmaz, gecikme faizi isleme ucundan dogar (web ile ayni kural).
const kalemTipleri = ['aidat', 'demirbas', 'olaganustu', 'sayac', 'diger'];

/// Toplu tahakkukun HEDEFI (sihirbazin "Kime" adimi).
enum TopluKapsam { tumu, blok, secili }

/// Toplu borclandirma govdesi — ONIZLEME ve ISLEME AYNI govdeyi kullanir.
class TopluBorcGovdesi {
  const TopluBorcGovdesi({
    required this.donem,
    required this.tanimId,
    required this.dagitim,
    required this.kalemTipi,
    required this.kapsam,
    this.tutarKurus,
    this.sonOdeme,
    this.tarih,
    this.aciklama,
    this.blok,
    this.unitIds = const [],
  });

  final String donem;
  final String tanimId;
  final String dagitim;
  final String kalemTipi;
  final TopluKapsam kapsam;

  /// `daire_basina`da HER daireye; digerlerinde DAGITILACAK TOPLAM. Bos ise
  /// (yalniz daire basina) daire tipinin varsayilani kullanilir.
  final int? tutarKurus;
  final DateTime? sonOdeme;
  final DateTime? tarih;
  final String? aciklama;
  final String? blok;
  final List<String> unitIds;

  static String _gun(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    final suzgec = switch (kapsam) {
      TopluKapsam.tumu => <String, dynamic>{},
      TopluKapsam.blok => {'blok': blok},
      TopluKapsam.secili => {'unit_ids': unitIds},
    };
    return {
      'donem': donem,
      'gelir_gider_tanim_id': tanimId,
      'suzgec': suzgec,
      'son_odeme_tarihi': sonOdeme == null ? null : _gun(sonOdeme!),
      'tarih': tarih == null ? null : _gun(tarih!),
      'aciklama': aciklama,
      'kalem_tipi': kalemTipi,
      'dagitim': dagitim,
      // AYNI ALAN IKI ANLAM TASIMAZ (web ile ayni): daire basina modunda
      // tutar her daireye, digerlerinde dagitilacak toplam.
      if (dagitim == 'daire_basina')
        'tutar_kurus': tutarKurus
      else
        'toplam_tutar_kurus': tutarKurus,
    };
  }
}

class TopluSatir {
  const TopluSatir({
    required this.unitId,
    required this.unitNo,
    this.tutarKurus,
    this.atlamaNedeni,
    this.hedefCozulemedi = false,
  });

  final String unitId;
  final String unitNo;
  final int? tutarKurus;
  final String? atlamaNedeni;
  final bool hedefCozulemedi;

  factory TopluSatir.fromJson(Map<String, dynamic> j) => TopluSatir(
        unitId: (j['unit_id'] as String?) ?? '',
        unitNo: (j['unit_no'] as String?) ?? '',
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt(),
        atlamaNedeni: j['atlama_nedeni'] as String?,
        hedefCozulemedi: (j['hedef_cozulemedi'] as bool?) ?? false,
      );
}

class TopluOnizleme {
  const TopluOnizleme({
    required this.islenecek,
    required this.atlanacak,
    required this.hedefsiz,
    required this.toplamKurus,
    required this.satirlar,
  });

  final int islenecek;
  final int atlanacak;
  final int hedefsiz;
  final int toplamKurus;
  final List<TopluSatir> satirlar;

  List<TopluSatir> get _islenen =>
      [for (final s in satirlar) if (s.atlamaNedeni == null && s.tutarKurus != null) s];

  /// Ozet: en yuksek ve en dusuk bes tutar (daire tablosu YOK — plan §2.2).
  List<TopluSatir> get enYuksek =>
      (_islenen..sort((a, b) => b.tutarKurus!.compareTo(a.tutarKurus!))).take(5).toList();
  List<TopluSatir> get enDusuk =>
      (_islenen..sort((a, b) => a.tutarKurus!.compareTo(b.tutarKurus!))).take(5).toList();
  List<TopluSatir> get atlananlar =>
      [for (final s in satirlar) if (s.atlamaNedeni != null) s];
  List<TopluSatir> get hedefsizler =>
      [for (final s in satirlar) if (s.hedefCozulemedi) s];

  factory TopluOnizleme.fromJson(Map<String, dynamic> j) => TopluOnizleme(
        islenecek: (j['islenecek'] as num?)?.toInt() ?? 0,
        atlanacak: (j['atlanacak'] as num?)?.toInt() ?? 0,
        hedefsiz: (j['hedefsiz'] as num?)?.toInt() ?? 0,
        toplamKurus: (j['toplam_kurus'] as num?)?.toInt() ?? 0,
        satirlar: [
          for (final m in (j['satirlar'] as List?) ?? const [])
            if (m is Map) TopluSatir.fromJson(Map<String, dynamic>.from(m)),
        ],
      );
}

/// `DuesAssessmentResult` — kac olustu, hangisi neden atlandi.
class TahakkukSonucu {
  const TahakkukSonucu({required this.olusan, required this.atlananlar, this.partiId});

  final int olusan;

  /// (P253 §C-4) Toplu tahakkuk partisi — "Geri al" icin; yoksa null.
  final String? partiId;
  final List<({String? unitNo, String neden})> atlananlar;

  factory TahakkukSonucu.fromJson(Map<String, dynamic> j) {
    final created = (j['created'] as List?) ?? const [];
    return TahakkukSonucu(
      // Tekil yolda `olusan` eski surumlerde 0 donebilir; `created` sayilir.
      olusan: (j['olusan'] as num?)?.toInt() ?? created.length,
      partiId: j['parti_id'] as String?,
      atlananlar: [
        for (final m in (j['atlananlar'] as List?) ?? const [])
          if (m is Map)
            (unitNo: m['unit_no'] as String?, neden: (m['neden'] as String?) ?? ''),
      ],
    );
  }
}

/// `GET /borclandirma/gecikme-faizi/onizleme`.
class FaizOnizleme {
  const FaizOnizleme({
    required this.uygulaniyor,
    required this.toplamFarkKurus,
    required this.adet,
    required this.donem,
  });

  final bool uygulaniyor;
  final int toplamFarkKurus;
  final int adet;
  final String donem;

  factory FaizOnizleme.fromJson(Map<String, dynamic> j) => FaizOnizleme(
        uygulaniyor: (j['uygulaniyor'] as bool?) ?? false,
        toplamFarkKurus: (j['toplam_fark_kurus'] as num?)?.toInt() ?? 0,
        adet: ((j['items'] as List?) ?? const []).length,
        donem: (j['donem'] as String?) ?? '',
      );
}

/// Odeme yontemi — sunucu `DuesYontem`.
const odemeYontemleri = ['elden', 'havale', 'kart', 'diger'];
