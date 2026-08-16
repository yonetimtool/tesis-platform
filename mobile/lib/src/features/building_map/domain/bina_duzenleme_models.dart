/// "Bina Düzenleme" (D-viz Rev-2) editor domain modelleri.
///
/// Editor iki kaynagi birlestirir:
///   * `GET /blocks`  → blok kutucuklari (BOS bloklar dahil; building-map yalniz
///     daire iceren bloklari doner, editor bos blogu da gostermeli).
///   * `GET /units`   → tum daireler (blok/kat/sira); istemci blok->kat->sira
///     gruplar (building-map blok=null'i "unplaced"a atar, editor kat gruplamasi
///     icin ham daire listesi kullanir).
///
/// Yazma (POST/PATCH/DELETE /blocks + /units) YALNIZ admin+yonetici (backend RBAC
/// zorlar). Blok-suz siteler: BuildingBlock satiri OLMADAN, daire blok=null.
library;

/// Bir bina blogu (`BlockOut`). Blok etiketi (`ad`) daire.blok ile zayif eslesir
/// (hard FK yok); [unitSayisi] o etiketi tasiyan daire sayisidir (silme guvenligi
/// — daire varsa DELETE 409 doner).
class BuildingBlock {
  const BuildingBlock({
    required this.id,
    required this.ad,
    this.unitSayisi = 0,
  });

  final String id;
  final String ad;
  final int unitSayisi;

  factory BuildingBlock.fromJson(Map<String, dynamic> json) => BuildingBlock(
    id: json['id'] as String? ?? '',
    ad: json['ad'] as String? ?? '',
    unitSayisi: (json['unit_sayisi'] as num?)?.toInt() ?? 0,
  );
}

/// Editordeki tek daire (`UnitOut`) — yerlesim (blok/kat/sira) ile.
class EditorUnit {
  const EditorUnit({
    required this.id,
    required this.no,
    this.blok,
    this.kat,
    this.sira,
    this.aktif = true,
    this.unitTipId,
    this.unitTipAd,
    this.unitGrupId,
    this.unitGrupAd,
  });

  final String id;
  final String no;
  final String? blok;
  final int? kat;
  final int? sira;
  final bool aktif;

  /// (P26) Siniflandirma. Ad da tasinir: hucre/liste ayri istek yapmadan
  /// etiketi cizebilsin. Tanim silinmisse `null` — uydurma etiket YOK.
  final String? unitTipId;
  final String? unitTipAd;
  final String? unitGrupId;
  final String? unitGrupAd;

  factory EditorUnit.fromJson(Map<String, dynamic> json) => EditorUnit(
    id: json['id'] as String? ?? '',
    no: json['no'] as String? ?? '',
    blok: json['blok'] as String?,
    kat: (json['kat'] as num?)?.toInt(),
    sira: (json['sira'] as num?)?.toInt(),
    aktif: json['aktif'] as bool? ?? true,
    unitTipId: json['unit_tip_id'] as String?,
    unitTipAd: json['unit_tip_ad'] as String?,
    unitGrupId: json['unit_grup_id'] as String?,
    unitGrupAd: json['unit_grup_ad'] as String?,
  );
}

/// `POST/PATCH /blocks` govdesi — blok etiketi (kisa alfanumerik, tire YOK).
/// Katlar blok kurulumunda degil, kat "+" akisinda eklenir.
class BlockDraft {
  const BlockDraft({required this.ad});

  final String ad;

  Map<String, dynamic> toJson() => {'ad': ad};
}

/// (P165) `GET /units/kat-onizleme` — bir kat silinirse NE KAYBEDILECEK.
///
/// SUNUCU SAYAR: daire basina sakin/tahakkuk/talep saymak elli daireli bir
/// katta elli istek demekti. Sayilar KATEGORI KATEGORI durur — "12 bagli
/// kayit" bir sey soylemez, "3 sakin, 9 tahakkuk" karar verdirir.
class KatOnizleme {
  const KatOnizleme({
    required this.daire,
    required this.sakin,
    required this.tahakkuk,
    required this.odeme,
    required this.talep,
    required this.rezervasyon,
    required this.maliKayit,
  });

  final int daire;
  final int sakin;
  final int tahakkuk;
  final int odeme;
  final int talep;
  final int rezervasyon;

  /// Tahakkuk ya da tahsilat var mi — SUNUCU isaretler.
  ///
  /// Digerleri yeniden olusturulabilir; bir TAHSILAT KAYDI olusturulamaz.
  /// Bu bayrak ayri uyariyi ve ikinci kapiyi acar.
  final bool maliKayit;

  /// Daire yoksa kaybedilecek bir sey de yoktur (tek onayla gider).
  bool get bos => daire == 0;

  factory KatOnizleme.fromJson(Map<String, dynamic> json) => KatOnizleme(
    daire: (json['daire'] as num?)?.toInt() ?? 0,
    sakin: (json['sakin'] as num?)?.toInt() ?? 0,
    tahakkuk: (json['tahakkuk'] as num?)?.toInt() ?? 0,
    odeme: (json['odeme'] as num?)?.toInt() ?? 0,
    talep: (json['talep'] as num?)?.toInt() ?? 0,
    rezervasyon: (json['rezervasyon'] as num?)?.toInt() ?? 0,
    maliKayit: json['mali_kayit'] as bool? ?? false,
  );
}

/// `POST/PATCH /units` govdesi — daire no (alfanumerik + tire) + yerlesim.
/// Blok-suz modda [blok] null gonderilir (implicit tek blok).
class EditorUnitDraft {
  const EditorUnitDraft({
    required this.no,
    this.blok,
    this.kat,
    this.sira,
    this.unitTipId,
    this.unitGrupId,
  });

  final String no;
  final String? blok;
  final int? kat;
  final int? sira;

  /// (P26) Siniflandirma — `null` gonderilir ve bu KALDIRMAK demektir
  /// (sunucu `exclude_unset` ile "gonderilmedi"den ayirir; burada alan HER
  /// ZAMAN gonderildigi icin form neyi secmisse o gecerlidir).
  final String? unitTipId;
  final String? unitGrupId;

  /// POST icin tam govde (yerlesim alanlari null olabilir).
  Map<String, dynamic> toJson() => {
    'no': no,
    'blok': blok,
    'kat': kat,
    'sira': sira,
    'unit_tip_id': unitTipId,
    'unit_grup_id': unitGrupId,
  };
}
