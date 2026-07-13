/// Tek-seferlik daire goruntuleme izni domain modelleri (KVKK) —
/// `contracts/openapi.yaml` UnitAccessRequest semasina uyar.
///
/// Akis: admin/yonetici bir daire icin izin TALEBI acar (durum=bekliyor) ->
/// dairenin sakini onaylar/reddeder -> onay TEK-KULLANIMLIK izin (used=false)
/// -> talep eden o dairenin ziyaretci/kargo kaydini ILK okudugunda tuketilir
/// (used=true). Sureye bagli DEGIL (one-shot).
library;

enum AccessRequestDurum {
  bekliyor('bekliyor', 'Bekliyor'),
  onaylandi('onaylandi', 'Onaylandı'),
  reddedildi('reddedildi', 'Reddedildi'),
  unknown('unknown', 'Bilinmeyen');

  const AccessRequestDurum(this.wire, this.label);

  final String wire;
  final String label;

  static AccessRequestDurum fromWire(String? value) =>
      AccessRequestDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => AccessRequestDurum.unknown,
      );
}

class UnitAccessRequest {
  const UnitAccessRequest({
    required this.id,
    required this.unitId,
    required this.grantedToYoneticiUserId,
    required this.durum,
    required this.used,
    required this.requestedAt,
    this.unitNo,
    this.yoneticiAd,
    this.grantedByResidentUserId,
    this.residentAd,
    this.decidedAt,
    this.usedAt,
  });

  final String id;
  final String unitId;
  final String? unitNo;

  /// Talebi acan yonetici VEYA admin (izin ona verilir).
  final String grantedToYoneticiUserId;
  final String? yoneticiAd;

  /// Karari veren sakin (karara kadar null).
  final String? grantedByResidentUserId;
  final String? residentAd;

  final AccessRequestDurum durum;

  /// true = izin tuketildi (talep eden bir kez gordu); tekrar 403.
  final bool used;

  final DateTime requestedAt;
  final DateTime? decidedAt;
  final DateTime? usedAt;

  bool get bekliyor => durum == AccessRequestDurum.bekliyor;

  /// Onayli ve HENUZ kullanilmamis — talep eden bir kez goruntuleyebilir.
  bool get kullanilabilir =>
      durum == AccessRequestDurum.onaylandi && !used;

  factory UnitAccessRequest.fromJson(Map<String, dynamic> json) =>
      UnitAccessRequest(
        id: json['id'] as String? ?? '',
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        grantedToYoneticiUserId:
            json['granted_to_yonetici_user_id'] as String? ?? '',
        yoneticiAd: json['yonetici_ad'] as String?,
        grantedByResidentUserId:
            json['granted_by_resident_user_id'] as String?,
        residentAd: json['resident_ad'] as String?,
        durum: AccessRequestDurum.fromWire(json['durum'] as String?),
        used: json['used'] as bool? ?? false,
        requestedAt:
            DateTime.tryParse(json['requested_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        decidedAt: json['decided_at'] == null
            ? null
            : DateTime.tryParse(json['decided_at'] as String? ?? ''),
        usedAt: json['used_at'] == null
            ? null
            : DateTime.tryParse(json['used_at'] as String? ?? ''),
      );
}

/// `POST /unit-access-request/bulk` sonucu — tenant'taki SAKINLI TUM daireler
/// icin toplu bekleyen talep. Per-daire sakin RIZASI korunur (baypas yok).
class BulkAccessRequestResult {
  const BulkAccessRequestResult({
    required this.created,
    required this.skipped,
    required this.items,
  });

  /// Yeni acilan bekleyen talep sayisi.
  final int created;

  /// Zaten acik/onayli oldugu icin atlanan daire sayisi.
  final int skipped;

  /// Yeni acilan talepler (daire adiyla).
  final List<UnitAccessRequest> items;

  factory BulkAccessRequestResult.fromJson(Map<String, dynamic> json) =>
      BulkAccessRequestResult(
        created: (json['created'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => UnitAccessRequest.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// `GET /unit-access-request/granted-units` ogesi — talebi acanin SU AN
/// goruntuleyebilecegi (onayli + kullanilmamis) daire. Ilk okumada tuketilir.
class GrantedUnit {
  const GrantedUnit({
    required this.requestId,
    required this.unitId,
    this.unitNo,
    this.decidedAt,
  });

  final String requestId;
  final String unitId;
  final String? unitNo;
  final DateTime? decidedAt;

  factory GrantedUnit.fromJson(Map<String, dynamic> json) => GrantedUnit(
        requestId: json['request_id'] as String? ?? '',
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        decidedAt: json['decided_at'] == null
            ? null
            : DateTime.tryParse(json['decided_at'] as String? ?? ''),
      );
}
