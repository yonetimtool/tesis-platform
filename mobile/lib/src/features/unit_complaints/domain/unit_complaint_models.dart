/// Daire sikayeti (D1) domain modelleri — `contracts/openapi.yaml`
/// UnitComplaint / UnitComplaintCreate semalarina uyar.
///
/// TAM ANONIM (D1 HARD kurali): sikayet eden (complainant) HICBIR alanda
/// DONMEZ. `notlar` serbest metni YALNIZ yonetim (admin+yonetici) icin dolu;
/// diger roller null gorur (deanonimlestirme/target-shaming riskini sinirlar).
/// Renk daire-basidir (yogunluk), tek sikayette degil — bkz. building-map.
library;

/// `unit_complaint_kategori` enum'unun istemci aynasi (Rev-1 genisleme).
///
/// KIMLIK / METIN AYRIMI (README §15): tur 12'de `label` (TR sabiti)
/// KALDIRILDI — cozucu tur 4'te eklenmisti
/// (`presentation/kategori_adi.dart` → `unitComplaintKategoriAdi`), ama
/// `my_complaints_screen` hala enum alanini okuyordu.
enum UnitComplaintKategori {
  gurultu('gurultu'),
  kapiOnuAyakkabi('kapi_onu_ayakkabi'),
  zararVerme('zarar_verme'),
  /// P22g (0013) — hurda arac, dagilmis esya, cop yigini; otopark
  /// baglamindan da bildirilebilir.
  goruntuKirliligi('goruntu_kirliligi'),
  diger('diger');

  const UnitComplaintKategori(this.wire);

  final String wire;

  static UnitComplaintKategori fromWire(String? value) =>
      UnitComplaintKategori.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => UnitComplaintKategori.diger,
      );
}

class UnitComplaint {
  const UnitComplaint({
    required this.id,
    required this.targetUnitId,
    required this.kategori,
    required this.durum,
    required this.createdAt,
    this.unitNo,
    this.notlar,
    this.complainantUserId,
    this.complainantAd,
    this.okundu,
  });

  final String id;
  final String targetUnitId;
  final String? unitNo;
  final UnitComplaintKategori kategori;

  /// Serbest metin — YALNIZ yonetim icin dolu (Rev-1); diger roller null.
  final String? notlar;

  /// 'acik' | 'kapali'.
  final String durum;

  final DateTime createdAt;

  /// Sikayet eden (complainant) — Rev-2 gizlilik: ARTIK HICBIR uctan donmez
  /// (yonetim dahil hep null). Alanlar geriye-uyum icin durur; gosterilmez.
  final String? complainantUserId;
  final String? complainantAd;

  /// (P24) ISTEGI YAPAN yoneticiye gore okundu mu — okuma durumu KISI
  /// BASINADIR. Sakin uclarinda (`/mine`) null gelir: okunmamis kuyrugu bir
  /// YONETIM kavramidir, sakine sizmaz.
  ///
  /// `null` "okunmus" DEMEK DEGILDIR; "bu uc okuma durumu bildirmiyor"
  /// demektir. Kuyruk gorunumu bu ayrimi korur (bkz. `okunmamisMi`).
  final bool? okundu;

  /// Kuyrukta ROZET/VURGU gerektiren satir: yalnizca uc okuma durumu
  /// bildirdiyse ve okunmamissa true.
  bool get okunmamisMi => okundu == false;

  bool get acik => durum == 'acik';

  /// (P146) Sahibi geri cekti — yonetime iletilmez. `acik` DEGILDIR, ama
  /// "cozuldu" da degildir; ekranda ayri gosterilir.
  bool get geriAlindi => durum == 'geri_alindi';

  /// Okundu isaretlendikten sonraki kopya (kuyrugu YERINDE gunceller).
  UnitComplaint okunduKopya() => UnitComplaint(
        id: id,
        targetUnitId: targetUnitId,
        kategori: kategori,
        durum: durum,
        createdAt: createdAt,
        unitNo: unitNo,
        notlar: notlar,
        complainantUserId: complainantUserId,
        complainantAd: complainantAd,
        okundu: true,
      );

  factory UnitComplaint.fromJson(Map<String, dynamic> json) => UnitComplaint(
        id: json['id'] as String? ?? '',
        targetUnitId: json['target_unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        kategori: UnitComplaintKategori.fromWire(json['kategori'] as String?),
        notlar: json['notlar'] as String?,
        durum: json['durum'] as String? ?? 'acik',
        complainantUserId: json['complainant_user_id'] as String?,
        complainantAd: json['complainant_ad'] as String?,
        okundu: json['okundu'] as bool?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /unit-complaints` govdesi (YALNIZ resident). Hedef DAIRE sikayet
/// edilir (target_unit_id); kategori zorunlu (varsayilan diger); notlar
/// opsiyonel. Ayni sakin ayni daireye AYNI ANDA yalniz BIR acik sikayet acar
/// (sunucu 409). Sikayet eden ANONIM tutulur.
class UnitComplaintDraft {
  const UnitComplaintDraft({
    required this.targetUnitId,
    required this.kategori,
    this.notlar,
  });

  final String targetUnitId;
  final UnitComplaintKategori kategori;
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'target_unit_id': targetUnitId,
        'kategori': kategori.wire,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}
