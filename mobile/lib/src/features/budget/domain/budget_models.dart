/// Butce modulunun domain modelleri — `contracts/openapi.yaml` Budget*
/// semalarina uyar. PARA HER YERDE INTEGER KURUS tasinir (float asla);
/// TL yalnizca GOSTERIM/GIRIS katmaninda ([formatKurusAsTl] /
/// [parseTlToKurus]) donusturulur.
library;

/// `budget_tip` enum'unun istemci aynasi.
enum BudgetTip {
  gelir('gelir', 'Gelir'),
  gider('gider', 'Gider');

  const BudgetTip(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

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

  /// KURUS (integer) — gosterimde [formatKurusAsTl] ile TL'ye cevrilir.
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

/// TL girisini (TR bicimi) INTEGER KURUS'a cevirir; gecersiz/sifir/negatif
/// girdide null. Kurallar:
///   * ',' her zaman ondaliktir; '.'lar binlik ayraci sayilir ("1.234,56").
///   * ',' yoksa ve TEK '.' sonda 1-2 hane birakiyorsa ondaliktir ("12.5");
///     aksi halde '.'lar binlik sayilir ("1.234").
///   * En fazla 2 ondalik hane.
int? parseTlToKurus(String input) {
  var s = input.trim().replaceAll('TL', '').replaceAll(' ', '');
  if (s.isEmpty || s.startsWith('-')) return null;

  String tamKisim;
  String ondalik = '';
  if (s.contains(',')) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    tamKisim = parts[0].replaceAll('.', '');
    ondalik = parts[1];
  } else {
    final dot = s.lastIndexOf('.');
    if (dot != -1 && s.length - dot - 1 <= 2 && s.indexOf('.') == dot) {
      tamKisim = s.substring(0, dot);
      ondalik = s.substring(dot + 1);
    } else {
      tamKisim = s.replaceAll('.', '');
    }
  }

  if (ondalik.length > 2) return null;
  if (tamKisim.isEmpty && ondalik.isEmpty) return null;
  final tam = int.tryParse(tamKisim.isEmpty ? '0' : tamKisim);
  final kurusPart =
      ondalik.isEmpty ? 0 : int.tryParse(ondalik.padRight(2, '0'));
  if (tam == null || kurusPart == null) return null;

  final kurus = tam * 100 + kurusPart;
  return kurus > 0 ? kurus : null;
}

/// INTEGER KURUS'u TR bicimli TL metnine cevirir (orn. 245000 -> "2.450,00").
String formatKurusAsTl(int kurus) {
  final negatif = kurus < 0;
  final abs = kurus.abs();
  final tam = abs ~/ 100;
  final ondalik = (abs % 100).toString().padLeft(2, '0');

  final digits = tam.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${negatif ? '-' : ''}$buf,$ondalik';
}
