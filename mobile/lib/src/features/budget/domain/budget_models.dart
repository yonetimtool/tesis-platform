/// Butce modulunun domain modelleri — `contracts/openapi.yaml` Budget*
/// semalarina uyar. PARA HER YERDE INTEGER KURUS tasinir (float asla);
/// TL yalnizca GOSTERIM/GIRIS katmaninda donusturulur: GIRIS burada
/// ([parseTlToKurus]), GOSTERIM `core/i18n/l10n.dart` icinde
/// (`tlSonEkli`/`tlIsaretli`). Tur 9'da `formatKurusAsTl` KALDIRILDI —
/// gruplamanin iki uygulamasi vardi, tek kaynak `tlTutar` oldu.
library;

import '../../../core/para.dart';

/// `budget_tip` enum'unun istemci aynasi.
///
/// KIMLIK / METIN AYRIMI (README §15): tur 6'da `label` (TR sabiti) KALDIRILDI;
/// gorunen ad `presentation/butce_tip_adi.dart` icinde cizim aninda cozulur.
enum BudgetTip {
  gelir('gelir'),
  gider('gider');

  const BudgetTip(this.wire);

  /// Backend enum degeri.
  final String wire;

  static BudgetTip fromWire(String? value) => BudgetTip.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => BudgetTip.gider,
      );
}

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.ad,
    required this.tip,
    required this.aktif,
  });

  final String id;
  final String ad;
  final BudgetTip tip;

  /// false = soft-delete: yeni kayit yazilamaz, eski kayitlar korunur.
  final bool aktif;

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        tip: BudgetTip.fromWire(json['tip'] as String?),
        aktif: json['aktif'] as bool? ?? true,
      );
}

class BudgetEntry {
  const BudgetEntry({
    required this.id,
    required this.kategoriId,
    required this.tip,
    required this.tutarKurus,
    required this.tarih,
    required this.kaynak,
    this.kategoriAd,
    this.aciklama,
    this.ilgiliPaymentId,
  });

  final String id;
  final String kategoriId;
  final String? kategoriAd;
  final BudgetTip tip;

  /// KURUS (integer) — gosterimde `tlSonEkli` ile TL'ye cevrilir.
  final int tutarKurus;

  final DateTime tarih;
  final String? aciklama;

  /// 'manuel' | 'aidat_odeme' (otomatik aidat geliri).
  final String kaynak;
  final String? ilgiliPaymentId;

  /// Basarili aidat odemesinden otomatik uretilen kayit mi?
  /// (Duzenlenemez/silinemez — aidat modulunun yetkisinde.)
  bool get otomatik => kaynak == 'aidat_odeme';

  factory BudgetEntry.fromJson(Map<String, dynamic> json) => BudgetEntry(
        id: json['id'] as String? ?? '',
        kategoriId: json['kategori_id'] as String? ?? '',
        kategoriAd: json['kategori_ad'] as String?,
        tip: BudgetTip.fromWire(json['tip'] as String?),
        tutarKurus: (json['tutar_kurus'] as num?)?.toInt() ?? 0,
        tarih: DateTime.tryParse(json['tarih'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        aciklama: json['aciklama'] as String?,
        kaynak: json['kaynak'] as String? ?? 'manuel',
        ilgiliPaymentId: json['ilgili_payment_id'] as String?,
      );
}

class BudgetCategorySummaryItem {
  const BudgetCategorySummaryItem({
    required this.kategoriId,
    required this.ad,
    required this.tip,
    required this.toplamKurus,
  });

  final String kategoriId;
  final String ad;
  final BudgetTip tip;
  final int toplamKurus;

  factory BudgetCategorySummaryItem.fromJson(Map<String, dynamic> json) =>
      BudgetCategorySummaryItem(
        kategoriId: json['kategori_id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        tip: BudgetTip.fromWire(json['tip'] as String?),
        toplamKurus: (json['toplam_kurus'] as num?)?.toInt() ?? 0,
      );
}

/// Kasa ozeti: bakiye = gelir - gider (NEGATIF olabilir).
class BudgetSummary {
  const BudgetSummary({
    required this.toplamGelirKurus,
    required this.toplamGiderKurus,
    required this.bakiyeKurus,
    required this.kategoriler,
  });

  final int toplamGelirKurus;
  final int toplamGiderKurus;
  final int bakiyeKurus;
  final List<BudgetCategorySummaryItem> kategoriler;

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
        toplamGelirKurus: (json['toplam_gelir_kurus'] as num?)?.toInt() ?? 0,
        toplamGiderKurus: (json['toplam_gider_kurus'] as num?)?.toInt() ?? 0,
        bakiyeKurus: (json['bakiye_kurus'] as num?)?.toInt() ?? 0,
        kategoriler: ((json['kategoriler'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetCategorySummaryItem.fromJson)
            .toList(),
      );
}

/// En yuksek gider kalemi (finansal ozet — agregat).
class GiderKalemi {
  const GiderKalemi({required this.ad, required this.toplamKurus});

  final String ad;
  final int toplamKurus;

  factory GiderKalemi.fromJson(Map<String, dynamic> json) => GiderKalemi(
        ad: json['ad'] as String? ?? '',
        toplamKurus: (json['toplam_kurus'] as num?)?.toInt() ?? 0,
      );
}

/// Aidat tahsilat blogu — yanitin bu kismi YALNIZ yonetimde dolar
/// (sakin/saha icin sunucu null doner).
class TahsilatOzet {
  const TahsilatOzet({
    required this.tahakkukKurus,
    required this.tahsilatKurus,
    required this.gecikenDaireSayisi,
    this.tahsilatOraniYuzde,
  });

  final int tahakkukKurus;
  final int tahsilatKurus;

  /// Tahakkuk 0 ise null (oran tanimsiz).
  final int? tahsilatOraniYuzde;
  final int gecikenDaireSayisi;

  factory TahsilatOzet.fromJson(Map<String, dynamic> json) => TahsilatOzet(
        tahakkukKurus: (json['tahakkuk_kurus'] as num?)?.toInt() ?? 0,
        tahsilatKurus: (json['tahsilat_kurus'] as num?)?.toInt() ?? 0,
        tahsilatOraniYuzde: (json['tahsilat_orani_yuzde'] as num?)?.toInt(),
        gecikenDaireSayisi:
            (json['geciken_daire_sayisi'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /reports/financial-summary` yaniti (Wave 2B) — rol-duyarli:
/// agregat alanlar herkese, [tahsilat] yalniz yonetime.
class FinancialSummary {
  const FinancialSummary({
    required this.toplamGelirKurus,
    required this.toplamGiderKurus,
    required this.bakiyeKurus,
    required this.enYuksekGiderler,
    this.donem,
    this.tahsilat,
  });

  final String? donem;
  final int toplamGelirKurus;
  final int toplamGiderKurus;
  final int bakiyeKurus;
  final List<GiderKalemi> enYuksekGiderler;
  final TahsilatOzet? tahsilat;

  factory FinancialSummary.fromJson(Map<String, dynamic> json) =>
      FinancialSummary(
        donem: json['donem'] as String?,
        toplamGelirKurus: (json['toplam_gelir_kurus'] as num?)?.toInt() ?? 0,
        toplamGiderKurus: (json['toplam_gider_kurus'] as num?)?.toInt() ?? 0,
        bakiyeKurus: (json['bakiye_kurus'] as num?)?.toInt() ?? 0,
        enYuksekGiderler: ((json['en_yuksek_giderler'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GiderKalemi.fromJson)
            .toList(),
        tahsilat: json['tahsilat'] == null
            ? null
            : TahsilatOzet.fromJson(json['tahsilat'] as Map<String, dynamic>),
      );
}

/// TL girisini (TR bicimi) INTEGER KURUS'a cevirir; gecersiz/sifir/negatif
/// girdide null. Kurallar:
///   * ',' her zaman ondaliktir; '.'lar binlik ayraci sayilir ("1.234,56").
///   * ',' yoksa ve TEK '.' sonda 1-2 hane birakiyorsa ondaliktir ("12.5");
///     aksi halde '.'lar binlik sayilir ("1.234").
///   * En fazla 2 ondalik hane.
int? parseTlToKurus(String input) {
  // (P49) AYRISTIRMA `core/para.dart`ta, POLITIKA burada: butce satirinda
  // 0 TL anlamsizdir. Bagimsiz bolum tanimlarinda ise 0 = MUAF gecerlidir;
  // ayni fonksiyonu paylasmak, birinin kuralini digerine dayatmak olurdu.
  final kurus = tlMetniniKurusaCevir(input);
  if (kurus == null) return null;
  return kurus > 0 ? kurus : null;
}

