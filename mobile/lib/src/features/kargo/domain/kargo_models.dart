/// Kargo modulunun domain modelleri — `contracts/openapi.yaml`
/// Kargo / KargoCreate / KargoUpdate semalarina uyar.
///
/// Akis (urun sahibi sabit): guvenlik gelen paketi kaydeder (daire + firma +
/// opsiyonel foto/not) -> dairenin TUM aktif sakinlerine push -> sakin
/// "Teslim aldim" isaretler YA DA guvenlik "Teslim et" der (P247 §3; ikinci
/// isaret 409 — teslim alan degismez).
/// RBAC (auth.md §4, visitor deseni): KAYIT yalniz security; TESLIM o
/// dairenin aktif sakini VEYA security; OKUMA yonetim+guvenlik tum gecmis, sakin kendi
/// dairesi; tesis_gorevlisi erisemez.
library;

/// `kargo_durum` enum'unun istemci aynasi.
///
/// KIMLIK / METIN AYRIMI (README §15): tur 6'da `label` (TR sabiti) KALDIRILDI
/// — son tuketici olan `kargo_screen` yerellestirildi; gorunen ad
/// `presentation/kargo_durum_adi.dart` icinde cizim aninda cozulur.
enum KargoDurum {
  bekliyor('bekliyor'),
  teslimAlindi('teslim_alindi'),
  unknown('unknown');

  const KargoDurum(this.wire);

  /// Backend enum degeri.
  final String wire;

  static KargoDurum fromWire(String? value) => KargoDurum.values.firstWhere(
    (d) => d.wire == value,
    orElse: () => KargoDurum.unknown,
  );
}

class Kargo {
  const Kargo({
    required this.id,
    required this.unitId,
    required this.firma,
    required this.durum,
    required this.kaydedenUserId,
    required this.createdAt,
    this.unitNo,
    this.fotoKey,
    this.fotoUrl,
    this.notlar,
    this.kaydedenAd,
    this.teslimAlanUserId,
    this.teslimAlanAd,
    this.teslimZamani,
    this.teslimEdenUserId,
    this.teslimEdenAd,
    this.gecikmis = false,
  });

  final String id;
  final String unitId;

  /// Daire numarasi (sunucu join ile doldurur).
  final String? unitNo;

  /// Kargo firmasi/tasiyici.
  final String firma;

  /// Opsiyonel paket fotografi — MinIO obje anahtari (varligi "foto var").
  final String? fotoKey;

  /// Goruntuleme icin kisa omurlu presigned GET URL (sunucu okumada uretir).
  final String? fotoUrl;

  final String? notlar;
  final KargoDurum durum;

  /// Kaydi acan guvenlik.
  final String kaydedenUserId;
  final String? kaydedenAd;

  /// Teslim alan sakin (teslim alinmadiysa null).
  final String? teslimAlanUserId;
  final String? teslimAlanAd;
  final DateTime? teslimZamani;

  /// (P247 §3) Teslimi guvenlik isaretlediyse o kisi (sakin kendisi
  /// isaretlediyse null).
  final String? teslimEdenUserId;
  final String? teslimEdenAd;

  /// (P247 §3) Sunucu hesaplar: `bekliyor` ve kayit esikten (3 gun) eski.
  /// Durum degismez; yalniz listede isaretlenir.
  final bool gecikmis;

  final DateTime createdAt;

  bool get bekliyor => durum == KargoDurum.bekliyor;

  factory Kargo.fromJson(Map<String, dynamic> json) => Kargo(
    id: json['id'] as String? ?? '',
    unitId: json['unit_id'] as String? ?? '',
    unitNo: json['unit_no'] as String?,
    firma: json['firma'] as String? ?? '',
    fotoKey: json['foto_key'] as String?,
    fotoUrl: json['foto_url'] as String?,
    notlar: json['notlar'] as String?,
    durum: KargoDurum.fromWire(json['durum'] as String?),
    kaydedenUserId: json['kaydeden_user_id'] as String? ?? '',
    kaydedenAd: json['kaydeden_ad'] as String?,
    teslimAlanUserId: json['teslim_alan_user_id'] as String?,
    teslimAlanAd: json['teslim_alan_ad'] as String?,
    teslimZamani: json['teslim_zamani'] == null
        ? null
        : DateTime.tryParse(json['teslim_zamani'] as String? ?? ''),
    teslimEdenUserId: json['teslim_eden_user_id'] as String?,
    teslimEdenAd: json['teslim_eden_ad'] as String?,
    gecikmis: json['gecikmis'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

/// `POST /kargo` govdesi (yalniz guvenlik). Daire NUMARASIYLA girilir
/// (visitor deseni); [fotoKey] mevcut presign akisindan gelir — null ise
/// JSON'a HIC yazilmaz.
class KargoDraft {
  const KargoDraft({
    required this.firma,
    required this.unitNo,
    this.fotoKey,
    this.notlar,
  });

  final String firma;
  final String unitNo;
  final String? fotoKey;

  /// Opsiyonel not; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? notlar;

  Map<String, dynamic> toJson() => {
    'firma': firma,
    'unit_no': unitNo,
    if (fotoKey != null) 'foto_key': fotoKey,
    if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
  };
}
