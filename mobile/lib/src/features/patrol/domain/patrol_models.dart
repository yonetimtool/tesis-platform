/// Tur (devriye) ekraninin domain modelleri — `contracts/openapi.yaml`'daki
/// AktifTur / PatrolWindowHistory / PatrolWindowOzet / PatrolPlanCheckpoint /
/// MePatrolWindowResponse semalarina uyar.
///
/// VERI AKISI (Faz 2 — README §10 KAPANDI): nokta bazli okutma durumunun
/// TEK KAYNAGI artik sunucudur (`GET /me/patrol-window`, pencere-geneli —
/// baska elemanin okutmasi da gorunur). Yerel birlesimin kalan tek rolu, bu
/// cihazin outbox'ta BEKLEYEN (henuz gonderilmemis) okutmalarini sunucu
/// verisinin uzerine "gonderiliyor" olarak bindirmektir — bkz.
/// [mergeCheckpointStatuses].
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

/// `GET /me/patrol-window` → checkpoints[] ogesi (MePatrolCheckpoint semasi).
/// `okutuldu` PENCERE-GENELIDIR: herhangi bir elemanin pencere araligindaki
/// okutmasi sayilir; zaman/kullanici penceredeki ILK scan'den gelir.
class MePatrolCheckpoint {
  const MePatrolCheckpoint({
    required this.checkpointId,
    required this.ad,
    required this.sira,
    required this.okutuldu,
    this.okutmaZamani,
    this.okutanUserId,
  });

  final String checkpointId;
  final String ad;
  final int sira;
  final bool okutuldu;
  final DateTime? okutmaZamani;
  final String? okutanUserId;

  factory MePatrolCheckpoint.fromJson(Map<String, dynamic> json) =>
      MePatrolCheckpoint(
        checkpointId: json['checkpoint_id'] as String,
        ad: json['ad'] as String? ?? '',
        sira: (json['sira'] as num?)?.toInt() ?? 0,
        okutuldu: json['okutuldu'] as bool? ?? false,
        okutmaZamani: json['okutma_zamani'] == null
            ? null
            : DateTime.parse(json['okutma_zamani'] as String).toUtc(),
        okutanUserId: json['okutan_user_id'] as String?,
      );
}

/// `GET /me/patrol-window` → windows[] ogesi (MePatrolWindowItem semasi):
/// pencere bilgisi + kendi checkpoint listesi (`sira` ASC).
class MePatrolWindowItem {
  const MePatrolWindowItem({
    required this.id,
    required this.patrolPlanId,
    required this.pencereBaslangic,
    required this.pencereBitis,
    required this.durum,
    required this.checkpoints,
    this.planAdi,
  });

  final String id;
  final String patrolPlanId;
  final String? planAdi;
  final DateTime pencereBaslangic;
  final DateTime pencereBitis;
  final PatrolWindowDurum durum;
  final List<MePatrolCheckpoint> checkpoints;

  int get okutulanSayisi => checkpoints.where((c) => c.okutuldu).length;

  /// Ekranin mevcut gorunum modeline kopru: sayilar sunucu checkpoint
  /// listesinden turetilir (scheduler'in "tamamlandi" hesabiyla ayni kaynak).
  ActivePatrolWindow toActiveWindow() => ActivePatrolWindow(
        patrolWindowId: id,
        patrolPlanId: patrolPlanId,
        patrolPlanAd: planAdi,
        pencereBaslangic: pencereBaslangic,
        pencereBitis: pencereBitis,
        durum: durum,
        beklenenCheckpointSayisi: checkpoints.length,
        okutulanCheckpointSayisi: okutulanSayisi,
      );

  factory MePatrolWindowItem.fromJson(
    Map<String, dynamic> json, {
    List<MePatrolCheckpoint>? checkpoints,
  }) {
    final rawCps = json['checkpoints'];
    return MePatrolWindowItem(
      id: json['id'] as String,
      patrolPlanId: json['patrol_plan_id'] as String,
      planAdi: json['plan_adi'] as String?,
      pencereBaslangic:
          DateTime.parse(json['pencere_baslangic'] as String).toUtc(),
      pencereBitis: DateTime.parse(json['pencere_bitis'] as String).toUtc(),
      durum: patrolWindowDurumFromJson(json['durum'] as String?),
      checkpoints: checkpoints ??
          [
            for (final item in rawCps is List ? rawCps : const [])
              if (item is Map)
                MePatrolCheckpoint.fromJson(Map<String, dynamic>.from(item)),
          ],
    );
  }
}

/// `GET /me/patrol-window` yaniti (MePatrolWindowResponse semasi).
///
///   * [window]  — bitisi en yakin (en acil) aktif pencere; ust-duzey
///                 `checkpoints` alani bu pencerenin listesidir. Aktif
///                 pencere yoksa null (200 doner, hata DEGIL).
///   * [windows] — TUM aktif pencereler, `pencere_bitis` ASC (genelde 0-1).
class MePatrolWindowResponse {
  const MePatrolWindowResponse({
    required this.generatedAt,
    required this.window,
    required this.windows,
  });

  final DateTime generatedAt;
  final MePatrolWindowItem? window;
  final List<MePatrolWindowItem> windows;

  factory MePatrolWindowResponse.fromJson(Map<String, dynamic> json) {
    final rawWindow = json['window'];
    final rawCps = json['checkpoints'];
    final window = rawWindow is Map
        ? MePatrolWindowItem.fromJson(
            Map<String, dynamic>.from(rawWindow),
            checkpoints: [
              for (final item in rawCps is List ? rawCps : const [])
                if (item is Map)
                  MePatrolCheckpoint.fromJson(Map<String, dynamic>.from(item)),
            ],
          )
        : null;
    final rawWindows = json['windows'];
    final windows = [
      for (final item in rawWindows is List ? rawWindows : const [])
        if (item is Map)
          MePatrolWindowItem.fromJson(Map<String, dynamic>.from(item)),
    ];
    return MePatrolWindowResponse(
      generatedAt: json['generated_at'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(json['generated_at'] as String).toUtc(),
      window: window,
      // Savunmaci: windows[] bos ama window dolu gelirse tek pencere say.
      windows: windows.isEmpty && window != null ? [window] : windows,
    );
  }
}

/// Bir noktanin listedeki okutma durumu:
///
///   * [bekliyor]     — sunucuda okutma kaydi yok ve bu cihazin outbox'inda
///                      bekleyen okutmasi yok.
///   * [gonderiliyor] — bu cihazda okutuldu, kayit outbox'ta gonderim
///                      bekliyor (sunucuda henuz gorunmez; offline'da bile
///                      kullanici ilerlemesini gorur).
///   * [okutuldu]     — SUNUCU kaydi (pencere-geneli): bu cihaz veya baska
///                      bir elemanin okutmasi backend'e islenmis.
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

/// SUNUCU checkpoint durumunun (tek dogruluk kaynagi — `GET
/// /me/patrol-window`) uzerine bu cihazin outbox'ta BEKLEYEN (henuz
/// gonderilmemis) okutmalarini "gonderiliyor" olarak BINDIRIR.
///
/// Kurallar:
///   * Sunucu `okutuldu` diyorsa sonuc her zaman [CheckpointScanDurum.okutuldu]
///     (zaman sunucudan). Yerel kayit bunu degistiremez.
///   * Bindirme yalnizca BEKLEYEN kayitlar icindir ([OutboxEntry.isPending]);
///     `gonderildi` kayitlar bindirilmez — gonderilmis scan'lerin kaynagi
///     sunucudur. `kaliciHata` hicbir zaman sayilmaz.
///   * Kayit, `okutma_zamani` pencere icindeyse (`[baslangic, bitis)`) once
///     checkpoint_id ile, yoksa [uidByCheckpointId] uzerinden normalize NFC
///     UID ile eslesir (outbox kayitlari cogunlukla checkpoint_id tasimaz).
///
/// Sonuc `sira` ASC sirali doner.
List<CheckpointStatus> mergeCheckpointStatuses({
  required List<MePatrolCheckpoint> serverCheckpoints,
  required DateTime pencereBaslangic,
  required DateTime pencereBitis,
  required List<OutboxEntry> outboxEntries,
  Map<String, String> uidByCheckpointId = const {},
}) {
  // Pencere icindeki BEKLEYEN kayitlari bir kez suz.
  final pendingInWindow = <OutboxEntry>[
    for (final e in outboxEntries)
      if (e.isPending &&
          !e.okutmaZamani.isBefore(pencereBaslangic) &&
          e.okutmaZamani.isBefore(pencereBitis))
        e,
  ];

  final sorted = [...serverCheckpoints]
    ..sort((a, b) => a.sira.compareTo(b.sira));

  return [
    for (final cp in sorted)
      () {
        final rawUid = uidByCheckpointId[cp.checkpointId];
        final uid = rawUid == null ? null : _normalizeUid(rawUid);
        final planCp = PlanCheckpoint(
          checkpointId: cp.checkpointId,
          sira: cp.sira,
          ad: cp.ad.isEmpty ? null : cp.ad,
          nfcTagUid: rawUid,
        );

        if (cp.okutuldu) {
          return CheckpointStatus(
            checkpoint: planCp,
            durum: CheckpointScanDurum.okutuldu,
            okutmaZamani: cp.okutmaZamani,
          );
        }

        OutboxEntry? pending;
        for (final e in pendingInWindow) {
          if (e.checkpointId == cp.checkpointId ||
              (uid != null && _normalizeUid(e.nfcTagUid) == uid)) {
            pending = e;
            break;
          }
        }
        return CheckpointStatus(
          checkpoint: planCp,
          durum: pending == null
              ? CheckpointScanDurum.bekliyor
              : CheckpointScanDurum.gonderiliyor,
          okutmaZamani: pending?.okutmaZamani,
        );
      }(),
  ];
}
