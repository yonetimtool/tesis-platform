/// Site kurallari modulunun domain modelleri — `contracts/openapi.yaml`
/// SiteKurali / SiteKuraliCreate / SiteKuraliUpdate semalarina uyar.
///
/// Blog-tarzi icerik: yonetici liste tutar (ekle/duzenle/sil), TUM roller
/// okur; `sira` ile siralanir (kucuk once), baslikta arama yapilir.
/// RBAC (auth.md §4): CRUD admin+yonetici; okuma herkes. Push yok —
/// kurallar duyuru degil basvuru icerigi.
library;

class SiteKurali {
  const SiteKurali({
    required this.id,
    required this.baslik,
    required this.icerik,
    required this.sira,
    required this.olusturanUserId,
    required this.createdAt,
    this.fotoKey,
    this.fotoUrl,
    this.olusturanAd,
  });

  final String id;
  final String baslik;
  final String icerik;

  /// Opsiyonel gorsel — MinIO obje anahtari (varligi "foto var" demektir).
  final String? fotoKey;

  /// Goruntuleme icin kisa omurlu presigned GET URL (sunucu okumada uretir).
  final String? fotoUrl;

  /// Liste sirasi (kucuk once); sunucu sira ASC dondurur.
  final int sira;

  final String olusturanUserId;
  final String? olusturanAd;
  final DateTime createdAt;

  factory SiteKurali.fromJson(Map<String, dynamic> json) => SiteKurali(
        id: json['id'] as String? ?? '',
        baslik: json['baslik'] as String? ?? '',
        icerik: json['icerik'] as String? ?? '',
        fotoKey: json['foto_key'] as String?,
        fotoUrl: json['foto_url'] as String?,
        sira: (json['sira'] as num?)?.toInt() ?? 0,
        olusturanUserId: json['olusturan_user_id'] as String? ?? '',
        olusturanAd: json['olusturan_ad'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Baslik aramasi es kurali (ekranin ANLIK suzgeci — sunucudaki ILIKE ile
  /// ayni anlam: buyuk/kucuk harf duyarsiz icerme).
  bool baslikEslesir(String sorgu) =>
      baslik.toLowerCase().contains(sorgu.toLowerCase());
}

/// `POST /site-rules` / `PATCH /site-rules/{id}` govdesi (yonetim).
class SiteKuraliDraft {
  const SiteKuraliDraft({
    required this.baslik,
    required this.icerik,
    required this.sira,
    this.fotoKey,
    this.fotoKeyKaldir = false,
  });

  final String baslik;
  final String icerik;
  final int sira;

  /// Yeni/mevcut gorsel anahtari (presign akisindan).
  final String? fotoKey;

  /// PATCH'te gorseli KALDIRMAK icin acik null gonderimi (sunucu sozlesmesi:
  /// alan yoksa dokunulmaz, acik null kaldirir).
  final bool fotoKeyKaldir;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'icerik': icerik,
        'sira': sira,
        if (fotoKey != null)
          'foto_key': fotoKey
        else if (fotoKeyKaldir)
          'foto_key': null,
      };
}
