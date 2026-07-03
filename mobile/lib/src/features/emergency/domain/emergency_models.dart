/// Acil durum (panik) modulunun domain modelleri — `contracts/openapi.yaml`
/// EmergencyCreate / EmergencyAlert / TenantSettings semalarina uyar.
///
/// SOZLESME (dogrulandi): `POST /emergency` Idempotency-Key ZORUNLU (mukerrer
/// basim korumasi; ayni anahtar → 200 + mevcut alarm). Govde yalnizca
/// `gps_lat? / gps_lng? / notlar?` tasir — tetiklenme zamani SUNUCUDA atanir.
/// RBAC: admin + security + cleaning (resident 403).
library;

/// `POST /emergency` istek govdesi + Idempotency-Key ureticisi.
///
/// Anahtar, panik butonuna BASILDIGI anda sabitlenen [basisAni]'ndan
/// deterministik turetilir: onay/GPS/not eklenirken veya ag hatasi sonrasi
/// "tekrar dene"de AYNI istek atilir → backend cift alarm uretmez.
class EmergencyDraft {
  const EmergencyDraft({
    required this.basisAni,
    this.gpsLat,
    this.gpsLng,
    this.notlar,
  });

  /// Butona basilan an (UTC) — anahtarin parcasi, degistirilemez.
  final DateTime basisAni;

  final double? gpsLat;
  final double? gpsLng;
  final String? notlar;

  String get idempotencyKey =>
      'emergency|${basisAni.toUtc().toIso8601String()}';

  EmergencyDraft copyWith({
    Object? gpsLat = _sentinel,
    Object? gpsLng = _sentinel,
    Object? notlar = _sentinel,
  }) =>
      EmergencyDraft(
        basisAni: basisAni,
        gpsLat: gpsLat == _sentinel ? this.gpsLat : gpsLat as double?,
        gpsLng: gpsLng == _sentinel ? this.gpsLng : gpsLng as double?,
        notlar: notlar == _sentinel ? this.notlar : notlar as String?,
      );

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'gps_lat': ?gpsLat,
        'gps_lng': ?gpsLng,
        'notlar': ?notlar,
      };
}

/// `POST /emergency` yaniti (EmergencyAlert semasi).
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.tetiklenmeZamani,
    required this.durum,
    this.gpsLat,
    this.gpsLng,
    this.notlar,
  });

  final String id;
  final DateTime tetiklenmeZamani;

  /// `acik` | `cozuldu` (mobil yalnizca gosterir).
  final String durum;

  final double? gpsLat;
  final double? gpsLng;
  final String? notlar;

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) => EmergencyAlert(
        id: json['id'] as String,
        tetiklenmeZamani:
            DateTime.parse(json['tetiklenme_zamani'] as String).toUtc(),
        durum: json['durum'] as String? ?? 'acik',
        gpsLat: (json['gps_lat'] as num?)?.toDouble(),
        gpsLng: (json['gps_lng'] as num?)?.toDouble(),
        notlar: json['notlar'] as String?,
      );
}

/// Gonderim sonucu: 201 yeni alarm / 200 idempotent tekrar (mevcut alarm).
class EmergencySubmitResult {
  const EmergencySubmitResult({
    required this.alert,
    required this.wasDuplicate,
  });

  final EmergencyAlert alert;
  final bool wasDuplicate;
}

/// `GET /tenant/settings` yaniti (TenantSettings semasi) — mobil yalnizca
/// yonetim numarasini kullanir.
class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    required this.ad,
    this.acilDurumTelefon,
  });

  final String tenantId;
  final String ad;

  /// Acil durumda aranacak yonetim numarasi (tel: link). Panel'den admin
  /// ayarlar; bos olabilir → arama butonu gizlenir.
  final String? acilDurumTelefon;

  factory TenantSettings.fromJson(Map<String, dynamic> json) => TenantSettings(
        tenantId: json['tenant_id'] as String,
        ad: json['ad'] as String? ?? '',
        acilDurumTelefon: json['acil_durum_telefon'] as String?,
      );
}

/// Telefon numarasini `tel:` URI'sine cevirir. Gorsel ayraclar (bosluk,
/// tire, parantez, nokta) atilir; `+` ve rakamlar kalir. Aranabilir icerik
/// yoksa null — arama butonu hic gosterilmez.
Uri? telUri(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) return null;
  return Uri(scheme: 'tel', path: cleaned);
}
