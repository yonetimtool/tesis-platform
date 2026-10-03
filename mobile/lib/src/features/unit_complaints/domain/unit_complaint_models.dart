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
    this.okundu,
    this.suresiDoldu = false,
    this.asilsiz = false,
    this.asilsizGerekce,
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

  // (P253 §D) Sikayet edenin kimligi HICBIR role donmez (yonetici dahil);
  // `complainant_*` alanlari sozlesmeden KALDIRILDI — modelde de yok.

  /// (P253 §D) Yonetim "asilsiz" isaretledi mi + gerekcesi. Yonetime ve
  /// sikayeti ACAN sakinin kendisine doner.
  final bool asilsiz;
  final String? asilsizGerekce;

  /// (P24) ISTEGI YAPAN yoneticiye gore okundu mu — okuma durumu KISI
  /// BASINADIR. Sakin uclarinda (`/mine`) null gelir: okunmamis kuyrugu bir
  /// YONETIM kavramidir, sakine sizmaz.
  ///
  /// `null` "okunmus" DEMEK DEGILDIR; "bu uc okuma durumu bildirmiyor"
  /// demektir. Kuyruk gorunumu bu ayrimi korur (bkz. `okunmamisMi`).
  final bool? okundu;

  /// (P251 §3) Harita penceresinden eski: hala acik ama haritada
  /// SAYILMIYOR. Ayrinti ekrani bunu ayri baslik altinda gosterir.
  final bool suresiDoldu;

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
        okundu: true,
        suresiDoldu: suresiDoldu,
        asilsiz: asilsiz,
        asilsizGerekce: asilsizGerekce,
      );

  factory UnitComplaint.fromJson(Map<String, dynamic> json) => UnitComplaint(
        id: json['id'] as String? ?? '',
        targetUnitId: json['target_unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        kategori: UnitComplaintKategori.fromWire(json['kategori'] as String?),
        notlar: json['notlar'] as String?,
        durum: json['durum'] as String? ?? 'acik',
        okundu: json['okundu'] as bool?,
        suresiDoldu: (json['suresi_doldu'] as bool?) ?? false,
        asilsiz: (json['asilsiz'] as bool?) ?? false,
        asilsizGerekce: json['asilsiz_gerekce'] as String?,
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

/// (P253 §D) `GET /unit-complaints/kaynak-ozeti` — daireye gelen sikayetlerin
/// ORUNTUSU: sayi + farkli kaynak daire + tek kaynak uyarisi. Kimlik ve
/// kaynak ETIKETI yok.
class SikayetKaynakOzeti {
  const SikayetKaynakOzeti({
    required this.gun,
    required this.sikayetSayisi,
    required this.farkliKaynak,
    required this.tekKaynakYogun,
    required this.asilsizSayisi,
  });

  final int gun;
  final int sikayetSayisi;
  final int farkliKaynak;
  final bool tekKaynakYogun;
  final int asilsizSayisi;

  bool get bos => sikayetSayisi + asilsizSayisi == 0;

  factory SikayetKaynakOzeti.fromJson(Map<String, dynamic> j) => SikayetKaynakOzeti(
        gun: (j['gun'] as num?)?.toInt() ?? 30,
        sikayetSayisi: (j['sikayet_sayisi'] as num?)?.toInt() ?? 0,
        farkliKaynak: (j['farkli_kaynak'] as num?)?.toInt() ?? 0,
        tekKaynakYogun: (j['tek_kaynak_yogun'] as bool?) ?? false,
        asilsizSayisi: (j['asilsiz_sayisi'] as num?)?.toInt() ?? 0,
      );
}
