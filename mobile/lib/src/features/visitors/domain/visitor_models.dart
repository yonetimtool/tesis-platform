/// Ziyaretci modulunun domain modelleri — `contracts/openapi.yaml`
/// Visitor / VisitorCreate / VisitorUpdate semalarina uyar.
///
/// Akis (TEK HEDEF modeli, KVKK): guvenlik kaydeder + dairenin AKTIF bir
/// sakinini HEDEF secer -> YALNIZ o sakine push -> hedef sakin onaylar/reddeder
/// -> sonuc kaydi acan guvenlige. RBAC (auth.md §4): KAYIT yalniz security;
/// YANIT yalniz HEDEF sakin; OKUMA security tum gecmis + resident kendine
/// hedeflenen; admin/yonetici varsayilan kapali (tek-seferlik izinle);
/// tesis_gorevlisi erisemez.
library;

/// `visitor_durum` enum'unun istemci aynasi. GSM'e hazir: ileride arama
/// adimi eklenirse yeni deger [unknown]'a duser (eski surum COKMEZ).
enum VisitorDurum {
  bekliyor('bekliyor', 'Bekliyor'),
  onaylandi('onaylandi', 'Onaylandı'),
  reddedildi('reddedildi', 'Reddedildi'),
  unknown('unknown', 'Bilinmeyen');

  const VisitorDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  static VisitorDurum fromWire(String? value) => VisitorDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => VisitorDurum.unknown,
      );
}

class Visitor {
  const Visitor({
    required this.id,
    required this.unitId,
    required this.ziyaretciAd,
    required this.durum,
    required this.kaydedenUserId,
    required this.targetResidentUserId,
    required this.createdAt,
    this.unitNo,
    this.notlar,
    this.kaydedenAd,
    this.targetResidentAd,
    this.yanitlayanUserId,
    this.yanitlayanAd,
    this.yanitZamani,
  });

  final String id;
  final String unitId;

  /// Daire numarasi (sunucu join ile doldurur — liste/karti icin).
  final String? unitNo;

  final String ziyaretciAd;
  final String? notlar;
  final VisitorDurum durum;

  /// Kaydi acan guvenlik (sonuc push'unun hedefi).
  final String kaydedenUserId;
  final String? kaydedenAd;

  /// HEDEF sakin (bildirim/gorunurluk/karar sahibi — tek hedef modeli).
  final String targetResidentUserId;
  final String? targetResidentAd;

  /// Yaniti veren sakin (ilk yanit kazanir; yanitsizsa null).
  final String? yanitlayanUserId;
  final String? yanitlayanAd;
  final DateTime? yanitZamani;

  final DateTime createdAt;

  bool get bekliyor => durum == VisitorDurum.bekliyor;

  factory Visitor.fromJson(Map<String, dynamic> json) => Visitor(
        id: json['id'] as String? ?? '',
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        ziyaretciAd: json['ziyaretci_ad'] as String? ?? '',
        notlar: json['notlar'] as String?,
        durum: VisitorDurum.fromWire(json['durum'] as String?),
        kaydedenUserId: json['kaydeden_user_id'] as String? ?? '',
        kaydedenAd: json['kaydeden_ad'] as String?,
        targetResidentUserId: json['target_resident_user_id'] as String? ?? '',
        targetResidentAd: json['target_resident_ad'] as String?,
        yanitlayanUserId: json['yanitlayan_user_id'] as String?,
        yanitlayanAd: json['yanitlayan_ad'] as String?,
        yanitZamani: json['yanit_zamani'] == null
            ? null
            : DateTime.tryParse(json['yanit_zamani'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /visitors` govdesi (yalniz guvenlik). Guvenlik daireyi NUMARASIYLA
/// girer; ardindan `GET /units/by-no/{unit_no}/residents` ile o dairenin AKTIF
/// sakinlerinden HEDEF sakini secer (target_resident_user_id — zorunlu). Sunucu
/// hedefin o dairenin aktif sakini oldugunu dogrular (aksi 422).
class VisitorDraft {
  const VisitorDraft({
    required this.ziyaretciAd,
    required this.unitNo,
    required this.targetResidentUserId,
    this.notlar,
  });

  final String ziyaretciAd;
  final String unitNo;

  /// Guvenligin sectigi hedef sakin (bildirilecek + karar verecek tek sakin).
  final String targetResidentUserId;

  /// Opsiyonel not; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'ziyaretci_ad': ziyaretciAd,
        'unit_no': unitNo,
        'target_resident_user_id': targetResidentUserId,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}

/// `GET /units/by-no/{unit_no}/residents` ogesi — hedef sakin secicisi.
class UnitResidentBrief {
  const UnitResidentBrief({required this.userId, required this.ad});

  final String userId;
  final String ad;

  factory UnitResidentBrief.fromJson(Map<String, dynamic> json) =>
      UnitResidentBrief(
        userId: json['user_id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
      );
}
