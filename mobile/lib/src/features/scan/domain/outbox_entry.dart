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
    this.status = OutboxStatus.bekliyor,
    this.attemptCount = 0,
    this.lastError,
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

  final OutboxStatus status;

  /// Kac kez gonderim denendigi (teshis + backoff bilgisi).
  final int attemptCount;

  /// Son denemenin hata mesaji (varsa; kullaniciya gosterilebilir).
  final String? lastError;

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
      );

  OutboxEntry copyWith({
    OutboxStatus? status,
    int? attemptCount,
    Object? lastError = _sentinel,
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
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError == _sentinel ? this.lastError : lastError as String?,
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
        'status': _statusJson[status],
        'attempt_count': attemptCount,
        if (lastError != null) 'last_error': lastError,
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
        status: _statusFromJson(json['status'] as String?),
        attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] as String?,
        outcome: switch (json['outcome'] as String?) {
          'created' => OutboxOutcome.created,
          'duplicate' => OutboxOutcome.duplicate,
          _ => null,
        },
      );
}
