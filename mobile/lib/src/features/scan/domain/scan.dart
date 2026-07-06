/// Tur kaniti (NFC okutma) gonderiminin domain modelleri —
/// `contracts/openapi.yaml`'daki ScanCreate / ScanEvent semalarina uyar.
library;

/// `POST /scans` istek govdesi (ScanCreate). Backend `nfc_tag_uid`'i
/// checkpoint'e eslestirir; [checkpointId] verilirse dogrudan kullanilir.
class ScanDraft {
  const ScanDraft({
    required this.nfcTagUid,
    required this.okutmaZamani,
    this.checkpointId,
    this.gpsLat,
    this.gpsLng,
    this.sdmPiccData,
    this.sdmCmac,
  });

  /// Okutulan NFC etiketi (sozlesme formati: "04:A3:B2:C1:90:00").
  final String nfcTagUid;

  /// Cihazin okuttugu an (UTC). Offline gecikmeli gonderilebilir.
  final DateTime okutmaZamani;

  final String? checkpointId;
  final double? gpsLat;
  final double? gpsLng;

  /// NTAG424 SDM ENCPICCData (32 hex) — etiketin NDEF URL'inden. NTAG21x'te
  /// veya ayristirilamadiginda null; scan SDM'siz de kabul edilir
  /// (imza_dogrulandi'yi SUNUCU hesaplar; govdede gonderilmez — deprecated).
  final String? sdmPiccData;

  /// NTAG424 SDMMAC (16 hex) — [sdmPiccData] ile BIRLIKTE anlamli.
  final String? sdmCmac;

  Map<String, dynamic> toJson() => {
        'nfc_tag_uid': nfcTagUid,
        'okutma_zamani': okutmaZamani.toUtc().toIso8601String(),
        if (checkpointId != null) 'checkpoint_id': checkpointId,
        if (gpsLat != null) 'gps_lat': gpsLat,
        if (gpsLng != null) 'gps_lng': gpsLng,
        // Sozlesme: iki alan BIRLIKTE gonderilir; biri eksikse ikisi de
        // atlanir (backend anahtarsiz/alansiz scan'i yine kabul eder).
        if (sdmPiccData != null && sdmCmac != null) ...{
          'sdm_picc_data': sdmPiccData,
          'sdm_cmac': sdmCmac,
        },
      };

  /// Idempotency-Key: ayni (etiket, okutma ani) icin sabit → offline kuyrukta
  /// cift gonderim ayni kaydi dondurur (backend 200 + mevcut kayit).
  String get idempotencyKey =>
      '$nfcTagUid|${okutmaZamani.toUtc().toIso8601String()}';
}

/// `POST /scans` yaniti (ScanEvent) — olusturulan/mevcut tur kaniti.
class ScanEvent {
  const ScanEvent({
    required this.id,
    required this.guardId,
    required this.checkpointId,
    required this.nfcTagUid,
    required this.okutmaZamani,
    required this.imzaDogrulandi,
    this.patrolWindowId,
  });

  final String id;
  final String guardId;
  final String checkpointId;
  final String? patrolWindowId;
  final String nfcTagUid;
  final DateTime okutmaZamani;
  final bool imzaDogrulandi;

  factory ScanEvent.fromJson(Map<String, dynamic> json) => ScanEvent(
        id: json['id'] as String,
        guardId: json['guard_id'] as String,
        checkpointId: json['checkpoint_id'] as String,
        patrolWindowId: json['patrol_window_id'] as String?,
        nfcTagUid: json['nfc_tag_uid'] as String,
        okutmaZamani: DateTime.parse(json['okutma_zamani'] as String),
        imzaDogrulandi: json['imza_dogrulandi'] as bool? ?? false,
      );
}

/// Gonderim sonucu: yaniti + yeni kayit mi yoksa idempotent tekrar mi (200)
/// oldugunu tasir.
class ScanSubmitResult {
  const ScanSubmitResult({required this.event, required this.wasDuplicate});

  final ScanEvent event;

  /// true → backend ayni Idempotency-Key ile mevcut kaydi dondurdu (200).
  final bool wasDuplicate;
}
