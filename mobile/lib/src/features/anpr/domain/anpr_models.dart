/// ANPR (plaka okuma) olaylari — `contracts/openapi.yaml` AnprEventOut.
///
/// Sunucu tarafi P16'da yazildi: kamera kutusu `X-ANPR-Key` ile olay yazar,
/// olay bir DEFTER kaydidir ve gecise cevrilir. Mobil taraf iki sey gosterir:
/// olay AKISI (ne okundu, ne oldu) ve ONAY KUYRUGU (dusuk guvenli okumalar).
///
/// KIMLIK / METIN AYRIMI (README §15): enum'lar GORUNEN METIN TASIMAZ.
library;

/// `anpr_olay_durum` enum'unun istemci aynasi.
enum AnprDurum {
  islendi('islendi'),
  onayBekliyor('onay_bekliyor'),
  yokSayildi('yok_sayildi'),
  hata('hata');

  const AnprDurum(this.wire);
  final String wire;

  static AnprDurum fromWire(String? w) => switch (w) {
    'onay_bekliyor' => AnprDurum.onayBekliyor,
    'yok_sayildi' => AnprDurum.yokSayildi,
    'hata' => AnprDurum.hata,
    _ => AnprDurum.islendi,
  };
}

/// `anpr_yon` aynasi. `bilinmiyor` GERCEK bir haldir: P15'te olculdu —
/// Frigate yon bilgisi URETMEZ.
enum AnprYon {
  giris('giris'),
  cikis('cikis'),
  bilinmiyor('bilinmiyor');

  const AnprYon(this.wire);
  final String wire;

  static AnprYon fromWire(String? w) => switch (w) {
    'giris' => AnprYon.giris,
    'cikis' => AnprYon.cikis,
    _ => AnprYon.bilinmiyor,
  };
}

class AnprOlay {
  const AnprOlay({
    required this.id,
    required this.kaynak,
    required this.kaynakOlayId,
    required this.plaka,
    required this.zaman,
    required this.yon,
    required this.durum,
    required this.createdAt,
    this.kamera,
    this.guven,
    this.durumNedeni,
    this.vehiclePassId,
  });

  final String id;

  /// frigate | hikvision | dahua | manuel
  final String kaynak;
  final String kaynakOlayId;

  /// NORMALIZE plaka (sunucu normalize eder).
  final String plaka;
  final DateTime zaman;
  final String? kamera;
  final AnprYon yon;

  /// 0..1 okuma guveni; null = kaynak guven bildirmedi.
  final double? guven;
  final AnprDurum durum;

  /// Kisa KOD (PII tasimaz): dusuk_guven, zaten_iceride, acik_gecis_yok,
  /// otomatik_cikis_kapali, elle_reddedildi, anpr_plaka_bicimi...
  final String? durumNedeni;

  /// Acilan/kapanan gecis; onay bekleyen ve yok sayilan olayda null.
  final String? vehiclePassId;

  final DateTime createdAt;

  /// Insan karari bekliyor mu.
  bool get onayBekliyor => durum == AnprDurum.onayBekliyor;

  /// Guven yuzdesi (0-100) — null ise gosterilmez.
  int? get guvenYuzde => guven == null ? null : (guven! * 100).round();

  factory AnprOlay.fromJson(Map<String, dynamic> json) => AnprOlay(
    id: json['id'] as String? ?? '',
    kaynak: json['kaynak'] as String? ?? '',
    kaynakOlayId: json['kaynak_olay_id'] as String? ?? '',
    plaka: json['plaka'] as String? ?? '',
    zaman:
        DateTime.tryParse(json['zaman'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    kamera: json['kamera'] as String?,
    yon: AnprYon.fromWire(json['yon'] as String?),
    guven: (json['guven'] as num?)?.toDouble(),
    durum: AnprDurum.fromWire(json['durum'] as String?),
    durumNedeni: json['durum_nedeni'] as String?,
    vehiclePassId: json['vehicle_pass_id'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
