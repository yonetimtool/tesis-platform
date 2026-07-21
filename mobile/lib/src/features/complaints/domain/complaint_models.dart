/// Talep/Arıza (İş Emri) modulunun domain modelleri — `contracts/openapi.yaml`
/// Complaint / ComplaintPhoto / ComplaintStatusHistory / ComplaintCreate /
/// ComplaintConvertRequest / ComplaintResolveRequest / ComplaintDeclineRequest
/// semalarina uyar.
///
/// RBAC (kesin kural): ACMA security + tesis_gorevlisi + resident (acan
/// token'dan); yonetici/admin ACAMAZ. OKUMA acan roller yalniz KENDI
/// actiklarini, admin+yonetici tenant'taki tumunu; DONUSTUR/COZ/REDDET
/// (convert/resolve/decline) yalniz admin+yonetici.
///
/// `complaint_durum` durum makinesi: acik -> is_emri -> cozuldu; acik ->
/// cozuldu (dogrudan); acik -> reddedildi. Digerleri 422 invalid_transition.
library;

/// `complaint_durum` enum'unun istemci aynasi. Bilinmeyen/gelecekteki bir
/// deger `unknown`'a duser — asla parse hatasi vermez (ileriye-uyumlu).
enum TalepDurum { acik, isEmri, cozuldu, reddedildi, unknown }

/// Sunucudan gelen `durum` teline gore [TalepDurum] cozer.
TalepDurum talepDurumFromWire(String? s) => switch (s) {
  'acik' => TalepDurum.acik,
  'is_emri' => TalepDurum.isEmri,
  'cozuldu' => TalepDurum.cozuldu,
  'reddedildi' => TalepDurum.reddedildi,
  _ => TalepDurum.unknown,
};

/// [TalepDurum] uzerinde tel degeri erisimi (`convert`/filtre gonderiminde
/// kullanilir; `unknown` icin bos dizge doner — sunucuya asla yazilmamali).
extension TalepDurumWire on TalepDurum {
  String get wire => switch (this) {
    TalepDurum.acik => 'acik',
    TalepDurum.isEmri => 'is_emri',
    TalepDurum.cozuldu => 'cozuldu',
    TalepDurum.reddedildi => 'reddedildi',
    TalepDurum.unknown => '',
  };
}

/// `TalepOncelik` — `ComplaintConvertRequest.oncelik` teli.
enum TalepOncelik { dusuk, orta, yuksek }

extension TalepOncelikWire on TalepOncelik {
  String get wire => switch (this) {
    TalepOncelik.dusuk => 'dusuk',
    TalepOncelik.orta => 'orta',
    TalepOncelik.yuksek => 'yuksek',
  };
}

/// `ComplaintPhoto` semasinin istemci aynasi — OKUMA ciktisi (talep acmada
/// gonderilen `foto_keys` dizge listesinden FARKLI, bkz. [ComplaintDraft]).
class ComplaintPhoto {
  const ComplaintPhoto({
    required this.id,
    required this.fotoKey,
    required this.sira,
    this.fotoUrl,
  });

  final String id;
  final String fotoKey;

  /// Gorunum sirasi (0-index).
  final int sira;

  /// Goruntuleme icin kisa omurlu presigned GET URL.
  final String? fotoUrl;

  factory ComplaintPhoto.fromJson(Map<String, dynamic> json) =>
      ComplaintPhoto(
        id: json['id'] as String? ?? '',
        fotoKey: json['foto_key'] as String? ?? '',
        sira: (json['sira'] as num?)?.toInt() ?? 0,
        fotoUrl: json['foto_url'] as String?,
      );
}

/// `ComplaintStatusHistory` semasinin istemci aynasi — durum gecis
/// timeline'i satiri. `user_id` ASLA tutulmaz, yalniz `actor_role`.
class ComplaintHistory {
  const ComplaintHistory({
    required this.durum,
    required this.actorRole,
    required this.createdAt,
    this.sebep,
  });

  final TalepDurum durum;
  final String actorRole;

  /// Opsiyonel not (convert.not / resolve.cozum_notu / decline.sebep).
  final String? sebep;

  final DateTime createdAt;

  factory ComplaintHistory.fromJson(Map<String, dynamic> json) =>
      ComplaintHistory(
        durum: talepDurumFromWire(json['durum'] as String?),
        actorRole: json['actor_role'] as String? ?? '',
        sebep: json['sebep'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class Complaint {
  const Complaint({
    required this.id,
    required this.acanUserId,
    required this.baslik,
    required this.mesaj,
    required this.durum,
    required this.fotograflar,
    required this.gecmis,
    required this.createdAt,
    required this.updatedAt,
    this.acanAd,
    this.kategoriId,
    this.kategoriAd,
    this.isEmriId,
    this.isEmriDurum,
  });

  final String id;
  final String acanUserId;

  /// Acan kullanicinin adi (yonetim listesinde join ile doldurulur).
  final String? acanAd;

  final String baslik;
  final String mesaj;

  /// Talep kategorisi = yonetici-tanimli gorev kategorisi (task_category);
  /// null = belirtilmemis.
  final String? kategoriId;

  /// Kategori adi (join ile doldurulur).
  final String? kategoriAd;

  final TalepDurum durum;

  final List<ComplaintPhoto> fotograflar;

  /// Durum gecis timeline'i (created_at ASC).
  final List<ComplaintHistory> gecmis;

  /// Bagli is emri (Task) — talep donusturulmusse dolu.
  final String? isEmriId;

  /// Bagli is emrinin ozet durumu: 'acik' (atandi) | 'tamamlandi';
  /// [isEmriId] null ise null.
  final String? isEmriDurum;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: json['id'] as String? ?? '',
    acanUserId: json['acan_user_id'] as String? ?? '',
    acanAd: json['acan_ad'] as String?,
    baslik: json['baslik'] as String? ?? '',
    mesaj: json['mesaj'] as String? ?? '',
    kategoriId: json['kategori_id'] as String?,
    kategoriAd: json['kategori_ad'] as String?,
    durum: talepDurumFromWire(json['durum'] as String?),
    fotograflar: (json['fotograflar'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => ComplaintPhoto.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    gecmis: (json['gecmis'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => ComplaintHistory.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    isEmriId: json['is_emri_id'] as String?,
    isEmriDurum: json['is_emri_durum'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

/// `POST /complaints` govdesi. Sunucu siniri: baslik <= 200, mesaj <= 5000
/// (bos deger 422) — form ayni sinirlari istemcide de uygular.
///
/// [fotoKeys] OKUMA'daki `fotograflar` (bkz. [ComplaintPhoto]) ile KARISTIRILMAMALI
/// — bu, en fazla 3 obje-anahtari dizgesi (presign akisindan alinir).
class ComplaintDraft {
  const ComplaintDraft({
    required this.baslik,
    required this.mesaj,
    this.kategoriId,
    this.fotoKeys = const [],
  });

  final String baslik;
  final String mesaj;

  /// Opsiyonel talep kategorisi (task_category); null ise JSON'a HIC yazilmaz.
  final String? kategoriId;

  /// Opsiyonel gorseller (en fazla 3); her biri `/uploads/presign` ile
  /// alinan obje anahtari.
  final List<String> fotoKeys;

  Map<String, dynamic> toJson() => {
    'baslik': baslik,
    'mesaj': mesaj,
    if (kategoriId != null) 'kategori_id': kategoriId,
    'foto_keys': fotoKeys,
  };
}

/// `POST /complaints/{id}/convert` govdesi (admin + yonetici). Not: JSON
/// alan adi tam olarak `not` (Python tarafinda `not_` + alias) — [not_]
/// buna karsilik gelir.
class ComplaintConvertDraft {
  const ComplaintConvertDraft({
    required this.atananUserId,
    this.oncelik = TalepOncelik.orta,
    this.kategoriId,
    this.not_,
  });

  /// Atanan security veya tesis_gorevlisi (aksi 422 invalid_assignee).
  final String atananUserId;

  final TalepOncelik oncelik;

  /// Onaylanan/degistirilen kategori; verilmezse talebin mevcut kategorisi
  /// kullanilir.
  final String? kategoriId;

  /// Opsiyonel not; history satirinin `sebep` alanina yazilir. JSON alan adi
  /// literal olarak `not`.
  final String? not_;

  Map<String, dynamic> toJson() => {
    'atanan_user_id': atananUserId,
    'oncelik': oncelik.wire,
    if (kategoriId != null) 'kategori_id': kategoriId,
    if (not_ != null) 'not': not_,
  };
}

/// `POST /complaints/{id}/resolve` govdesi (admin + yonetici).
class ComplaintResolveDraft {
  const ComplaintResolveDraft({this.cozumNotu});

  final String? cozumNotu;

  Map<String, dynamic> toJson() => {
    if (cozumNotu != null) 'cozum_notu': cozumNotu,
  };
}

/// `POST /complaints/{id}/decline` govdesi (admin + yonetici). `sebep`
/// ZORUNLU.
class ComplaintDeclineDraft {
  const ComplaintDeclineDraft({required this.sebep});

  final String sebep;

  Map<String, dynamic> toJson() => {'sebep': sebep};
}
