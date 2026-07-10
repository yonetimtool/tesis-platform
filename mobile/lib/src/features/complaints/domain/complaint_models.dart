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

/// `complaint_kategori` enum'unun istemci aynasi (opsiyonel talep turu).
/// null = belirtilmemis (eski kayitlar — geriye uyumlu).
enum ComplaintKategori {
  gurultu('gurultu', 'Gurultu kirliligi'),
  goruntu('goruntu', 'Goruntu kirliligi'),
  diger('diger', 'Diger');

  const ComplaintKategori(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  /// null/bilinmeyen deger → null (kategori alani opsiyonel; durum'un
  /// aksine "unknown" gostermek yerine etiketsiz birakilir).
  static ComplaintKategori? fromWire(String? value) {
    for (final k in ComplaintKategori.values) {
      if (k.wire == value) return k;
    }
    return null;
  }
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
    this.kategori,
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

  /// Opsiyonel tur (gurultu/goruntu kirliligi vb.); null = belirtilmemis.
  final ComplaintKategori? kategori;

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
        kategori: ComplaintKategori.fromWire(json['kategori'] as String?),
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
    this.kategori,
    this.fotoKey,
  });

  final String baslik;
  final String mesaj;

  /// Opsiyonel tur; null ise JSON'a HIC yazilmaz (geriye uyumlu).
  final ComplaintKategori? kategori;

  final String? fotoKey;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'mesaj': mesaj,
        if (kategori != null) 'kategori': kategori!.wire,
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
