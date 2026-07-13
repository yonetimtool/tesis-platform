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
    this.katSayisi,
    this.unitSayisi = 0,
  });

  final String id;
  final String ad;
  final int? katSayisi;
  final int unitSayisi;

  factory BuildingBlock.fromJson(Map<String, dynamic> json) => BuildingBlock(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        katSayisi: (json['kat_sayisi'] as num?)?.toInt(),
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
  });

  final String id;
  final String no;
  final String? blok;
  final int? kat;
  final int? sira;
  final bool aktif;

  factory EditorUnit.fromJson(Map<String, dynamic> json) => EditorUnit(
        id: json['id'] as String? ?? '',
        no: json['no'] as String? ?? '',
        blok: json['blok'] as String?,
        kat: (json['kat'] as num?)?.toInt(),
        sira: (json['sira'] as num?)?.toInt(),
        aktif: json['aktif'] as bool? ?? true,
      );
}

/// `POST/PATCH /blocks` govdesi — blok etiketi (kisa alfanumerik, tire YOK) +
/// opsiyonel kat sayisi ipucu.
class BlockDraft {
  const BlockDraft({required this.ad, this.katSayisi});

  final String ad;
  final int? katSayisi;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        if (katSayisi != null) 'kat_sayisi': katSayisi,
      };
}

/// `POST/PATCH /units` govdesi — daire no (alfanumerik + tire) + yerlesim.
/// Blok-suz modda [blok] null gonderilir (implicit tek blok).
class EditorUnitDraft {
  const EditorUnitDraft({
    required this.no,
    this.blok,
    this.kat,
    this.sira,
  });

  final String no;
  final String? blok;
  final int? kat;
  final int? sira;

  /// POST icin tam govde (yerlesim alanlari null olabilir).
  Map<String, dynamic> toJson() => {
        'no': no,
        'blok': blok,
        'kat': kat,
        'sira': sira,
      };
}
