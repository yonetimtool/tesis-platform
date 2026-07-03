/// Tur (devriye) ekraninin domain modelleri — `contracts/openapi.yaml`'daki
/// AktifTur / PatrolWindowHistory / PatrolWindowOzet / PatrolPlanCheckpoint
/// semalarina uyar.
///
/// ONEMLI SOZLESME NOTU: mevcut uclarin hicbiri "bu pencerede HANGI
/// checkpoint'ler okutuldu" bilgisini nokta bazinda vermiyor (dashboard/live
/// ve /patrol-windows yalnizca SAYI dondurur; scan'lerin GET ucu yok). Bu
/// yuzden nokta bazli durum, plan checkpoint listesi + BU CIHAZIN yerel
/// okutma kaydinin (outbox) birlesimiyle uretilir — bkz.
/// [mergeCheckpointStatuses]. Detay: mobile/README.md §9 (eksik uc onerisi
/// §10'da DEV-A'ya flag'lendi).
library;

import '../../scan/domain/outbox_entry.dart';

/// PatrolWindowDurum semasi. [bilinmiyor] sozlesme disi degerler icin
/// güvenli fallback'tir (uygulama cokmesin).
enum PatrolWindowDurum { bekliyor, tamamlandi, kacirildi, bilinmiyor }

PatrolWindowDurum patrolWindowDurumFromJson(String? value) => switch (value) {
      'bekliyor' => PatrolWindowDurum.bekliyor,
      'tamamlandi' => PatrolWindowDurum.tamamlandi,
      'kacirildi' => PatrolWindowDurum.kacirildi,
      _ => PatrolWindowDurum.bilinmiyor,
    };

/// `GET /dashboard/live` → `aktif_turlar[]` ogesi (AktifTur semasi).
/// Aktif/bekleyen pencereler + okutulan/beklenen SAYILARI (nokta listesi yok).
class ActivePatrolWindow {
  const ActivePatrolWindow({
    required this.patrolWindowId,
    required this.patrolPlanId,
    required this.pencereBaslangic,
    required this.pencereBitis,
    required this.durum,
    this.patrolPlanAd,
    this.beklenenCheckpointSayisi = 0,
    this.okutulanCheckpointSayisi = 0,
  });

  final String patrolWindowId;
  final String patrolPlanId;
  final String? patrolPlanAd;

  /// Pencere sinirlari (UTC). Gosterimde `toLocal()` kullanilir.
  final DateTime pencereBaslangic;
  final DateTime pencereBitis;

  final PatrolWindowDurum durum;

  /// Sunucunun bildirdigi sayilar — TUM cihazlarin okutmalarini kapsar.
  final int beklenenCheckpointSayisi;
  final int okutulanCheckpointSayisi;

  bool isActiveAt(DateTime now) =>
      durum == PatrolWindowDurum.bekliyor &&
      !now.isBefore(pencereBaslangic) &&
      now.isBefore(pencereBitis);

  bool isUpcomingAt(DateTime now) =>
      durum == PatrolWindowDurum.bekliyor && now.isBefore(pencereBaslangic);

  factory ActivePatrolWindow.fromJson(Map<String, dynamic> json) =>
      ActivePatrolWindow(
        patrolWindowId: json['patrol_window_id'] as String,
        patrolPlanId: json['patrol_plan_id'] as String,
        patrolPlanAd: json['patrol_plan_ad'] as String?,
        pencereBaslangic:
            DateTime.parse(json['pencere_baslangic'] as String).toUtc(),
        pencereBitis: DateTime.parse(json['pencere_bitis'] as String).toUtc(),
        durum: patrolWindowDurumFromJson(json['durum'] as String?),
        beklenenCheckpointSayisi:
            (json['beklenen_checkpoint_sayisi'] as num?)?.toInt() ?? 0,
        okutulanCheckpointSayisi:
            (json['okutulan_checkpoint_sayisi'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /patrol-windows` ogesi (PatrolWindowHistory semasi) — gecmis pencere.
class PatrolWindowHistoryItem {
  const PatrolWindowHistoryItem({
    required this.id,
    required this.patrolPlanId,
    required this.pencereBaslangic,
    required this.pencereBitis,
    required this.durum,
    this.planAdi,
    this.beklenenCheckpointSayisi = 0,
    this.okutulanCheckpointSayisi = 0,
  });

  final String id;
  final String patrolPlanId;
  final String? planAdi;
  final DateTime pencereBaslangic;
  final DateTime pencereBitis;
  final PatrolWindowDurum durum;
  final int beklenenCheckpointSayisi;
  final int okutulanCheckpointSayisi;

  factory PatrolWindowHistoryItem.fromJson(Map<String, dynamic> json) =>
      PatrolWindowHistoryItem(
        id: json['id'] as String,
        patrolPlanId: json['patrol_plan_id'] as String,
        planAdi: json['plan_adi'] as String?,
        pencereBaslangic:
            DateTime.parse(json['pencere_baslangic'] as String).toUtc(),
        pencereBitis: DateTime.parse(json['pencere_bitis'] as String).toUtc(),
        durum: patrolWindowDurumFromJson(json['durum'] as String?),
        beklenenCheckpointSayisi:
            (json['beklenen_checkpoint_sayisi'] as num?)?.toInt() ?? 0,
        okutulanCheckpointSayisi:
            (json['okutulan_checkpoint_sayisi'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /patrol-windows` → `ozet` (PatrolWindowOzet) — filtrelenmis TUM kume
/// uzerinden sayilar (sayfa ile sinirli degil).
class PatrolWindowOzet {
  const PatrolWindowOzet({
    this.toplam = 0,
    this.tamamlandi = 0,
    this.kacirildi = 0,
    this.bekliyor = 0,
  });

  final int toplam;
  final int tamamlandi;
  final int kacirildi;
  final int bekliyor;

  factory PatrolWindowOzet.fromJson(Map<String, dynamic> json) =>
      PatrolWindowOzet(
        toplam: (json['toplam'] as num?)?.toInt() ?? 0,
        tamamlandi: (json['tamamlandi'] as num?)?.toInt() ?? 0,
        kacirildi: (json['kacirildi'] as num?)?.toInt() ?? 0,
        bekliyor: (json['bekliyor'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /patrol-plans/{id}/checkpoints` ogesi (PatrolPlanCheckpoint) —
/// genisletilmis `checkpoint` alanindan ad + nfc_tag_uid duzlestirilir.
class PlanCheckpoint {
  const PlanCheckpoint({
    required this.checkpointId,
    required this.sira,
    this.ad,
    this.nfcTagUid,
  });

  final String checkpointId;
  final int sira;

  /// Nokta adi (genisletilmis yanittan; yoksa /checkpoints ile zenginlestirilir).
  final String? ad;

  /// Yerel okutma eslestirmesinin anahtari: outbox kayitlari cogunlukla
  /// checkpoint_id TASIMAZ (backend UID'den cozer), UID ile eslesir.
  final String? nfcTagUid;

  PlanCheckpoint copyWith({String? ad, String? nfcTagUid}) => PlanCheckpoint(
        checkpointId: checkpointId,
        sira: sira,
        ad: ad ?? this.ad,
        nfcTagUid: nfcTagUid ?? this.nfcTagUid,
      );

  factory PlanCheckpoint.fromJson(Map<String, dynamic> json) {
    final cp = json['checkpoint'] as Map<String, dynamic>?;
    return PlanCheckpoint(
      checkpointId: json['checkpoint_id'] as String,
      sira: (json['sira'] as num?)?.toInt() ?? 0,
      ad: cp?['ad'] as String?,
      nfcTagUid: cp?['nfc_tag_uid'] as String?,
    );
  }
}

/// Bir noktanin BU CIHAZA gore okutma durumu (yerel birlesim sonucu):
///
///   * [bekliyor]     — bu cihazda pencere icinde okutma kaydi yok. Baska bir
///                      cihaz okutmus olabilir (sunucu sayisi ayrica gosterilir).
///   * [gonderiliyor] — okutuldu, kayit outbox'ta gonderim bekliyor/gidiyor
///                      (offline'da bile kullanici ilerlemesini gorur).
///   * [okutuldu]     — okutuldu ve backend kabul etti (201/200).
enum CheckpointScanDurum { bekliyor, gonderiliyor, okutuldu }

/// Liste satirinin gorunum modeli: plan noktasi + yerel okutma durumu.
class CheckpointStatus {
  const CheckpointStatus({
    required this.checkpoint,
    required this.durum,
    this.okutmaZamani,
  });

  final PlanCheckpoint checkpoint;
  final CheckpointScanDurum durum;

  /// Bu cihazdaki eslesen okutmanin ani (varsa).
  final DateTime? okutmaZamani;

  bool get okundu => durum != CheckpointScanDurum.bekliyor;
}

String _normalizeUid(String uid) => uid.trim().toUpperCase();

/// Plan checkpoint listesi ile bu cihazin okutma kaydini (outbox — bekleyen +
/// gonderilmis) BIRLESTIRIR. Sozlesmede nokta bazli sunucu verisi olmadigi
/// icin tek dogruluk kaynagimiz bu yerel kayittir (eksik uc onerisi:
/// README §10 — DEV-A notu).
///
/// Eslestirme kurali: kayit `kaliciHata` degilse ve `okutma_zamani` pencere
/// icindeyse (`[baslangic, bitis)`), once checkpoint_id ile, yoksa
/// normalize edilmis NFC UID ile eslesir. Ayni noktaya birden fazla kayit
/// varsa en "ileri" durum kazanir (okutuldu > gonderiliyor).
List<CheckpointStatus> mergeCheckpointStatuses({
  required List<PlanCheckpoint> checkpoints,
  required DateTime pencereBaslangic,
  required DateTime pencereBitis,
  required List<OutboxEntry> outboxEntries,
}) {
  // Pencere icindeki kullanilabilir kayitlari bir kez suz.
  final inWindow = <OutboxEntry>[
    for (final e in outboxEntries)
      if (e.status != OutboxStatus.kaliciHata &&
          !e.okutmaZamani.isBefore(pencereBaslangic) &&
          e.okutmaZamani.isBefore(pencereBitis))
        e,
  ];

  return [
    for (final cp in checkpoints)
      () {
        final uid = cp.nfcTagUid == null ? null : _normalizeUid(cp.nfcTagUid!);
        OutboxEntry? best;
        for (final e in inWindow) {
          final matches = e.checkpointId == cp.checkpointId ||
              (uid != null && _normalizeUid(e.nfcTagUid) == uid);
          if (!matches) continue;
          if (best == null ||
              (e.status == OutboxStatus.gonderildi &&
                  best.status != OutboxStatus.gonderildi)) {
            best = e;
          }
        }
        final durum = switch (best?.status) {
          null => CheckpointScanDurum.bekliyor,
          OutboxStatus.gonderildi => CheckpointScanDurum.okutuldu,
          _ => CheckpointScanDurum.gonderiliyor,
        };
        return CheckpointStatus(
          checkpoint: cp,
          durum: durum,
          okutmaZamani: best?.okutmaZamani,
        );
      }(),
  ];
}
