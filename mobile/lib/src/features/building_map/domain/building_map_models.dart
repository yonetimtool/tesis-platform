/// Bina semasi (D-viz-1) domain modelleri — `GET /unit-complaints/building-map`
/// yanitina uyar. Yerlesim (blok/kat/sira) + ANONIM yogunluk (sayim + renk).
///
/// Anonimlik (D1 HARD kurali): yanitta sikayet eden verisi YOKTUR; yalniz
/// daire-basi acik sayim + renk doner. Yerlesimi eksik daireler [BuildingMap.unplaced]
/// kovasinda gelir.
///
/// Yerlesim girisi (blok/kat/sira) YALNIZ yonetim (admin+yonetici) tarafindan
/// `PATCH /units/{id}/layout` ile yapilir (backend RBAC zorlar).
library;

/// Yogunluk rengi (acik sikayet sayisina gore): 0-2 yesil, 3-4 sari, 5+ kirmizi.
enum DensityRenk {
  yesil('yesil', 'Yeşil'),
  sari('sari', 'Sarı'),
  kirmizi('kirmizi', 'Kırmızı'),
  unknown('unknown', 'Bilinmeyen');

  const DensityRenk(this.wire, this.label);

  final String wire;
  final String label;

  static DensityRenk fromWire(String? value) => DensityRenk.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => DensityRenk.unknown,
      );
}

/// Haritada tek daire — yerlesim + anonim sayim/renk.
class BuildingMapUnit {
  const BuildingMapUnit({
    required this.unitId,
    required this.unitNo,
    required this.complaintCount,
    required this.color,
    this.blok,
    this.kat,
    this.sira,
  });

  final String unitId;
  final String unitNo;
  final String? blok;
  final int? kat;
  final int? sira;

  /// ACIK sikayet sayisi — YALNIZ yonetim (shows_density) icin dolu; digerinde
  /// null (resident/saha hangi dairenin kac sikayeti oldugunu bilemez, Rev-1).
  final int? complaintCount;

  /// Yogunluk rengi — YALNIZ yonetim icin dolu; digerinde null (yapi gorunumu).
  final DensityRenk? color;

  /// Yerlesim tam mi (blok + kat girilmis)? Haritada cizilebilir demektir.
  bool get yerlesik => blok != null && kat != null;

  factory BuildingMapUnit.fromJson(Map<String, dynamic> json) => BuildingMapUnit(
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String? ?? '',
        blok: json['blok'] as String?,
        kat: (json['kat'] as num?)?.toInt(),
        sira: (json['sira'] as num?)?.toInt(),
        // null (yapi gorunumu) korunur — 0 ile karistirilmaz.
        complaintCount: (json['complaint_count'] as num?)?.toInt(),
        color: json['color'] == null
            ? null
            : DensityRenk.fromWire(json['color'] as String?),
      );
}

/// Bir bloktaki tek kat — sira'ya gore sirali daireler.
class BuildingMapKat {
  const BuildingMapKat({required this.kat, required this.units});

  final int kat;
  final List<BuildingMapUnit> units;

  factory BuildingMapKat.fromJson(Map<String, dynamic> json) => BuildingMapKat(
        kat: (json['kat'] as num?)?.toInt() ?? 0,
        units: (json['units'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => BuildingMapUnit.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// Tek blok — kat'a gore sirali (0=zemin altta).
class BuildingMapBlok {
  const BuildingMapBlok({required this.blok, required this.katlar});

  final String blok;
  final List<BuildingMapKat> katlar;

  factory BuildingMapBlok.fromJson(Map<String, dynamic> json) => BuildingMapBlok(
        blok: json['blok'] as String? ?? '',
        katlar: (json['katlar'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => BuildingMapKat.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// Cizilebilir bina yapisi: blok -> kat -> daire ve yerlesimsizler.
/// ROL-FARKINDA (Rev-1): [showsDensity] yonetimde true (sayim+renk dolu);
/// resident/security/gorevli icin false (yalniz yapi).
class BuildingMap {
  const BuildingMap({
    required this.bloklar,
    required this.unplaced,
    this.showsDensity = false,
  });

  final List<BuildingMapBlok> bloklar;
  final List<BuildingMapUnit> unplaced;

  /// true: complaint_count/color dolu (yonetim gorunumu); false: yalniz yapi.
  final bool showsDensity;

  /// Tenant'ta hic daire var mi (yerlesik veya degil)?
  bool get bos => bloklar.isEmpty && unplaced.isEmpty;

  factory BuildingMap.fromJson(Map<String, dynamic> json) => BuildingMap(
        showsDensity: json['shows_density'] as bool? ?? false,
        bloklar: (json['bloklar'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => BuildingMapBlok.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        unplaced: (json['unplaced'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => BuildingMapUnit.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// `PATCH /units/{id}/layout` govdesi — yerlesim girisi (yonetim).
/// En az bir alan dolu olmali (sunucu bos govdeye 422 doner); girilen alanlar
/// gonderilir. Bir alani temizlemek icin acikca null gonderilebilir
/// ([clearBlok]/[clearKat]/[clearSira]).
class UnitLayoutDraft {
  const UnitLayoutDraft({
    this.blok,
    this.kat,
    this.sira,
    this.clearBlok = false,
    this.clearKat = false,
    this.clearSira = false,
  });

  final String? blok;
  final int? kat;
  final int? sira;
  final bool clearBlok;
  final bool clearKat;
  final bool clearSira;

  bool get bos =>
      blok == null &&
      kat == null &&
      sira == null &&
      !clearBlok &&
      !clearKat &&
      !clearSira;

  Map<String, dynamic> toJson() => {
        if (clearBlok) 'blok': null else if (blok != null) 'blok': blok,
        if (clearKat) 'kat': null else if (kat != null) 'kat': kat,
        if (clearSira) 'sira': null else if (sira != null) 'sira': sira,
      };
}
