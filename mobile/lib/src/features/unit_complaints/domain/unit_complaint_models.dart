/// Daire sikayeti (D1) domain modelleri — `contracts/openapi.yaml`
/// UnitComplaint / UnitComplaintCreate semalarina uyar.
///
/// TAM ANONIM (D1 HARD kurali): sikayet eden (complainant) HICBIR alanda
/// DONMEZ. `notlar` serbest metni YALNIZ yonetim (admin+yonetici) icin dolu;
/// diger roller null gorur (deanonimlestirme/target-shaming riskini sinirlar).
/// Renk daire-basidir (yogunluk), tek sikayette degil — bkz. building-map.
library;

/// `unit_complaint_kategori` enum'unun istemci aynasi (Rev-1 genisleme).
enum UnitComplaintKategori {
  gurultu('gurultu', 'Gürültü'),
  kapiOnuAyakkabi('kapi_onu_ayakkabi', 'Kapı önü / ayakkabı'),
  zararVerme('zarar_verme', 'Zarar verme'),
  diger('diger', 'Diğer');

  const UnitComplaintKategori(this.wire, this.label);

  final String wire;
  final String label;

  static UnitComplaintKategori fromWire(String? value) =>
      UnitComplaintKategori.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => UnitComplaintKategori.diger,
      );
}

class UnitComplaint {
  const UnitComplaint({
    required this.id,
    required this.targetUnitId,
    required this.kategori,
    required this.durum,
    required this.createdAt,
    this.unitNo,
    this.notlar,
    this.complainantUserId,
    this.complainantAd,
  });

  final String id;
  final String targetUnitId;
  final String? unitNo;
  final UnitComplaintKategori kategori;

  /// Serbest metin — YALNIZ yonetim icin dolu (Rev-1); diger roller null.
  final String? notlar;

  /// 'acik' | 'kapali'.
  final String durum;

  final DateTime createdAt;

  /// Sikayet eden (complainant) — Rev-2 gizlilik: ARTIK HICBIR uctan donmez
  /// (yonetim dahil hep null). Alanlar geriye-uyum icin durur; gosterilmez.
  final String? complainantUserId;
  final String? complainantAd;

  bool get acik => durum == 'acik';

  factory UnitComplaint.fromJson(Map<String, dynamic> json) => UnitComplaint(
        id: json['id'] as String? ?? '',
        targetUnitId: json['target_unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        kategori: UnitComplaintKategori.fromWire(json['kategori'] as String?),
        notlar: json['notlar'] as String?,
        durum: json['durum'] as String? ?? 'acik',
        complainantUserId: json['complainant_user_id'] as String?,
        complainantAd: json['complainant_ad'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /unit-complaints` govdesi (YALNIZ resident). Hedef DAIRE sikayet
/// edilir (target_unit_id); kategori zorunlu (varsayilan diger); notlar
/// opsiyonel. Ayni sakin ayni daireye AYNI ANDA yalniz BIR acik sikayet acar
/// (sunucu 409). Sikayet eden ANONIM tutulur.
class UnitComplaintDraft {
  const UnitComplaintDraft({
    required this.targetUnitId,
    required this.kategori,
    this.notlar,
  });

  final String targetUnitId;
  final UnitComplaintKategori kategori;
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'target_unit_id': targetUnitId,
        'kategori': kategori.wire,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}
