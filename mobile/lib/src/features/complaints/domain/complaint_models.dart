/// Sikayet/oneri modulunun domain modelleri — `contracts/openapi.yaml`
/// Complaint / ComplaintCreate / ComplaintUpdate semalarina uyar.
///
/// RBAC (auth.md §4, kesin kural): ACMA security + tesis_gorevlisi +
/// resident (acan token'dan); yonetici/admin ACAMAZ. OKUMA acan roller
/// yalniz KENDI actiklarini, admin+yonetici tenant'taki tumunu;
/// DURUM/YANIT (PATCH) yalniz admin+yonetici.
library;

/// `complaint_durum` enum'unun istemci aynasi.
enum ComplaintDurum {
  acik('acik', 'Acik'),
  inceleniyor('inceleniyor', 'Inceleniyor'),
  cozuldu('cozuldu', 'Cozuldu'),
  unknown('unknown', 'Bilinmeyen');

  const ComplaintDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  static ComplaintDurum fromWire(String? value) =>
      ComplaintDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => ComplaintDurum.unknown,
      );
}

class Complaint {
  const Complaint({
    required this.id,
    required this.baslik,
    required this.mesaj,
    required this.durum,
    required this.acanUserId,
    required this.createdAt,
    required this.updatedAt,
    this.acanAd,
    this.fotoKey,
    this.fotoUrl,
    this.yoneticiYaniti,
    this.yanitlayanUserId,
    this.yanitZamani,
  });

  final String id;
  final String baslik;
  final String mesaj;
  final ComplaintDurum durum;
  final String acanUserId;

  /// Acan sakinin adi (yonetim listesinde join ile doldurulur).
  final String? acanAd;

  /// Opsiyonel gorsel — MinIO obje anahtari (varligi "foto var" demektir).
  final String? fotoKey;

  /// Goruntuleme icin kisa omurlu presigned GET URL (sunucu okumada uretir).
  final String? fotoUrl;

  final String? yoneticiYaniti;
  final String? yanitlayanUserId;
  final DateTime? yanitZamani;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get yanitli => yoneticiYaniti != null;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String? ?? '',
        baslik: json['baslik'] as String? ?? '',
        mesaj: json['mesaj'] as String? ?? '',
        durum: ComplaintDurum.fromWire(json['durum'] as String?),
        acanUserId: json['acan_user_id'] as String? ?? '',
        acanAd: json['acan_ad'] as String?,
        fotoKey: json['foto_key'] as String?,
        fotoUrl: json['foto_url'] as String?,
        yoneticiYaniti: json['yonetici_yaniti'] as String?,
        yanitlayanUserId: json['yanitlayan_user_id'] as String?,
        yanitZamani: json['yanit_zamani'] == null
            ? null
            : DateTime.tryParse(json['yanit_zamani'] as String? ?? ''),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /complaints` govdesi. Sunucu siniri: baslik <= 200, mesaj <= 5000
/// (bos deger 422) — form ayni sinirlari istemcide de uygular. [fotoKey]
/// opsiyonel; null ise JSON'a HIC yazilmaz.
class ComplaintDraft {
  const ComplaintDraft({
    required this.baslik,
    required this.mesaj,
    this.fotoKey,
  });

  final String baslik;
  final String mesaj;
  final String? fotoKey;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'mesaj': mesaj,
        if (fotoKey != null) 'foto_key': fotoKey,
      };
}

/// `PATCH /complaints/{id}` govdesi (yonetim yaniti). En az bir alan dolu
/// olmali (sunucu bos govdeye 422 doner); null alanlar JSON'a yazilmaz.
class ComplaintReplyDraft {
  const ComplaintReplyDraft({this.durum, this.yoneticiYaniti});

  final ComplaintDurum? durum;
  final String? yoneticiYaniti;

  bool get bos => durum == null && yoneticiYaniti == null;

  Map<String, dynamic> toJson() => {
        if (durum != null) 'durum': durum!.wire,
        if (yoneticiYaniti != null) 'yonetici_yaniti': yoneticiYaniti,
      };
}
