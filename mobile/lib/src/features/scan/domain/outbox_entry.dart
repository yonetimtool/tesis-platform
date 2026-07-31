/// Offline outbox'in domain modelleri. Okutulan her scan, gonderilene kadar
/// kalici kuyrukta bir [OutboxEntry] olarak yasar.
library;

import 'scan.dart';

/// Kuyruktaki kaydin durumu (durum makinesi):
///
///   bekliyor → gonderiliyor → gonderildi        (201/200)
///                       ↘ bekliyor              (ag/timeout/5xx/auth — retry)
///                       ↘ kaliciHata            (404 vb. — retry YAPILMAZ)
enum OutboxStatus {
  /// Gonderim sirasi bekleniyor (yeni veya retry'a dusmus).
  bekliyor,

  /// Su anda `POST /scans` deneniyor. Uygulama bu durumda olurken
  /// olurse acilista `bekliyor`a geri alinir (idempotency-key sayesinde
  /// yeniden gonderim guvenlidir).
  gonderiliyor,

  /// Backend kabul etti (201 yeni / 200 idempotent tekrar).
  gonderildi,

  /// Kalici hata (orn. 404 — etiket hicbir checkpoint ile eslesmedi).
  /// Yeniden denenmez; kullanici listeden gorup temizleyebilir.
  kaliciHata,
}

/// [OutboxStatus] ↔ JSON string esleme (dosyada okunabilir kalsin diye).
const _statusJson = {
  OutboxStatus.bekliyor: 'bekliyor',
  OutboxStatus.gonderiliyor: 'gonderiliyor',
  OutboxStatus.gonderildi: 'gonderildi',
  OutboxStatus.kaliciHata: 'kalici_hata',
};

OutboxStatus _statusFromJson(String? value) => _statusJson.entries
    .firstWhere(
      (e) => e.value == value,
      orElse: () => const MapEntry(OutboxStatus.bekliyor, 'bekliyor'),
    )
    .key;

/// Basarili gonderimin turu — kullaniciya "yeni kayit" / "zaten kayitliydi"
/// ayrimini gostermek icin saklanir.
enum OutboxOutcome { created, duplicate }

/// Kalici kuyruktaki tek bir okutma kaydi. Immutable; durum degisiklikleri
/// [copyWith] ile yeni nesne uretir.
class OutboxEntry {
  const OutboxEntry({
    required this.idempotencyKey,
    required this.nfcTagUid,
    required this.okutmaZamani,
    required this.enqueuedAt,
    this.checkpointId,
    this.gpsLat,
    this.gpsLng,
    this.konumDurumu,
    this.gpsDogrulukM,
    this.fotoKey,
    this.sdmPiccData,
    this.sdmCmac,
    this.status = OutboxStatus.bekliyor,
    this.attemptCount = 0,
    this.lastError,
    this.hataKodu,
    this.outcome,
  });

  /// Okuma ANINDA sabitlenen anahtar ([ScanDraft.idempotencyKey]) — kaydin
  /// kimligi. Ayni okutma iki kez gonderilse backend ayni kaydi doner.
  final String idempotencyKey;

  final String nfcTagUid;

  /// Etiketin okundugu an (UTC) — gonderim ne zaman olursa olsun degismez.
  final DateTime okutmaZamani;

  /// Kuyruga eklenme ani (UTC) — FIFO siralamasi liste sirasiyla korunur,
  /// bu alan yalnizca UI/teshis icindir.
  final DateTime enqueuedAt;

  final String? checkpointId;
  final double? gpsLat;
  final double? gpsLng;

  /// (P34) Konum durumu + dogrulugu; offline bekleyen kayitta kaybolmasin
  /// diye diske yazilir (konum OKUTMA aninda olculur, gonderim aninda degil —
  /// gonderim saatler sonra baska bir yerde olabilir).
  final String? konumDurumu;
  final double? gpsDogrulukM;

  /// (P34) Tur baslangic fotografinin depo anahtari. Fotograf kapisina
  /// takilan bir kayda SONRADAN eklenir ve ayni anahtarla yeniden gonderilir
  /// (ilk deneme reddedildigi icin sunucuda kayit YOKTUR — cakisma olmaz).
  final String? fotoKey;

  /// NTAG424 SDM alanlari (varsa) — offline bekleyen kayitta kaybolmamalari
  /// icin taslakla birlikte diske yazilir. Tekrar gonderimde ayni Idempotency-
  /// Key gittiginden backend SDM dogrulamasini atlar (tekrar ≠ replay).
  final String? sdmPiccData;
  final String? sdmCmac;

  final OutboxStatus status;

  /// Kac kez gonderim denendigi (teshis + backoff bilgisi).
  final int attemptCount;

  /// Son denemenin SUNUCU mesaji (varsa). Sunucu metinleri zaten
  /// yerellestirilmis gelir; oldugu gibi gosterilir.
  final String? lastError;

  /// Kalici hatanin SOZLESME KODU (`invalid_signature`, `replay_detected`...).
  ///
  /// NEDEN KOD: bu kayit DISKE yazilir. Tur 11'e kadar burada TR bir CUMLE
  /// duruyordu; kullanici dili degistirse bile kuyrukta eski dildeki metin
  /// kaliyordu. Kod tasiyip cizimde cozunce kayit dil-notr olur. Eski
  /// kayitlarda bu alan null'dir; ekran [lastError]'a duser (geri uyumluluk).
  final String? hataKodu;

  /// `gonderildi` durumunda: 201 → created, 200 → duplicate.
  final OutboxOutcome? outcome;

  bool get isPending =>
      status == OutboxStatus.bekliyor || status == OutboxStatus.gonderiliyor;

  /// Gonderim icin mevcut [ScanApi.submit]'in bekledigi taslak. Anahtar
  /// (uid, okutma_zamani)'ndan deterministik turetildigi icin buradaki
  /// [idempotencyKey] ile birebir aynidir.
  ScanDraft toDraft() => ScanDraft(
        nfcTagUid: nfcTagUid,
        okutmaZamani: okutmaZamani,
        checkpointId: checkpointId,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        konumDurumu: konumDurumu,
        gpsDogrulukM: gpsDogrulukM,
        fotoKey: fotoKey,
        sdmPiccData: sdmPiccData,
        sdmCmac: sdmCmac,
      );

  factory OutboxEntry.fromDraft(ScanDraft draft, {required DateTime now}) =>
      OutboxEntry(
        idempotencyKey: draft.idempotencyKey,
        nfcTagUid: draft.nfcTagUid,
        okutmaZamani: draft.okutmaZamani.toUtc(),
        enqueuedAt: now.toUtc(),
        checkpointId: draft.checkpointId,
        gpsLat: draft.gpsLat,
        gpsLng: draft.gpsLng,
        konumDurumu: draft.konumDurumu,
        gpsDogrulukM: draft.gpsDogrulukM,
        fotoKey: draft.fotoKey,
        sdmPiccData: draft.sdmPiccData,
        sdmCmac: draft.sdmCmac,
      );

  OutboxEntry copyWith({
    OutboxStatus? status,
    Object? fotoKey = _sentinel,
    int? attemptCount,
    Object? lastError = _sentinel,
    Object? hataKodu = _sentinel,
    Object? outcome = _sentinel,
  }) {
    return OutboxEntry(
      idempotencyKey: idempotencyKey,
      nfcTagUid: nfcTagUid,
      okutmaZamani: okutmaZamani,
      enqueuedAt: enqueuedAt,
      checkpointId: checkpointId,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      konumDurumu: konumDurumu,
      gpsDogrulukM: gpsDogrulukM,
      fotoKey: fotoKey == _sentinel ? this.fotoKey : fotoKey as String?,
      sdmPiccData: sdmPiccData,
      sdmCmac: sdmCmac,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError == _sentinel ? this.lastError : lastError as String?,
      hataKodu: hataKodu == _sentinel ? this.hataKodu : hataKodu as String?,
      outcome:
          outcome == _sentinel ? this.outcome : outcome as OutboxOutcome?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'nfc_tag_uid': nfcTagUid,
        'okutma_zamani': okutmaZamani.toUtc().toIso8601String(),
        'enqueued_at': enqueuedAt.toUtc().toIso8601String(),
        if (checkpointId != null) 'checkpoint_id': checkpointId,
        if (gpsLat != null) 'gps_lat': gpsLat,
        if (gpsLng != null) 'gps_lng': gpsLng,
        if (konumDurumu != null) 'konum_durumu': konumDurumu,
        if (gpsDogrulukM != null) 'gps_dogruluk_m': gpsDogrulukM,
        if (fotoKey != null) 'foto_key': fotoKey,
        if (sdmPiccData != null) 'sdm_picc_data': sdmPiccData,
        if (sdmCmac != null) 'sdm_cmac': sdmCmac,
        'status': _statusJson[status],
        'attempt_count': attemptCount,
        if (lastError != null) 'last_error': lastError,
        if (hataKodu != null) 'hata_kodu': hataKodu,
        if (outcome != null) 'outcome': outcome!.name,
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
        idempotencyKey: json['idempotency_key'] as String,
        nfcTagUid: json['nfc_tag_uid'] as String,
        okutmaZamani: DateTime.parse(json['okutma_zamani'] as String),
        enqueuedAt: DateTime.parse(json['enqueued_at'] as String),
        checkpointId: json['checkpoint_id'] as String?,
        gpsLat: (json['gps_lat'] as num?)?.toDouble(),
        gpsLng: (json['gps_lng'] as num?)?.toDouble(),
        konumDurumu: json['konum_durumu'] as String?,
        gpsDogrulukM: (json['gps_dogruluk_m'] as num?)?.toDouble(),
        fotoKey: json['foto_key'] as String?,
        sdmPiccData: json['sdm_picc_data'] as String?,
        sdmCmac: json['sdm_cmac'] as String?,
        status: _statusFromJson(json['status'] as String?),
        attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] as String?,
        hataKodu: json['hata_kodu'] as String?,
        outcome: switch (json['outcome'] as String?) {
          'created' => OutboxOutcome.created,
          'duplicate' => OutboxOutcome.duplicate,
          _ => null,
        },
      );
}
