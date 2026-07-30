/// Arac gecisi modelleri — `contracts/openapi.yaml` VehiclePass /
/// VehiclePassCreate semalarina uyar.
///
/// TEK SATIR gecisin TAMAMINI tutar: `girisZamani` her zaman dolu,
/// `cikisZamani` NULL iken arac ICERIDEDIR. Otopark dolulugu bu acik
/// satirlarin SAYIMIDIR (`GET /parking/occupancy`) — ayri sayac yok, yani
/// sayim ile kayit asla ayrisamaz.
///
/// RBAC (auth.md §4 / sozlesme): liste + giris + cikis YALNIZ admin +
/// security. Plaka kisisel veriye baglanabilir (KVKK); yonetici ve resident
/// gecis LISTESINI GORMEZ (403) — onlara agregat doluluk aciktir.
library;

class VehiclePass {
  const VehiclePass({
    required this.id,
    required this.plaka,
    required this.girisZamani,
    required this.ziyaretciMi,
    required this.kaydedenUserId,
    required this.createdAt,
    this.aracTanim,
    this.cikisZamani,
    this.unitId,
    this.unitNo,
    this.kaydedenAd,
  });

  final String id;

  /// NORMALIZE plaka ("34 abc 123" -> "34ABC123"). Sunucu normalize eder ve
  /// normalize halini dondurur; istemci bicim bilmek zorunda degildir.
  final String plaka;

  final String? aracTanim;
  final DateTime girisZamani;

  /// **null => arac HALA ICERIDE.**
  final DateTime? cikisZamani;

  final String? unitId;
  final String? unitNo;
  final bool ziyaretciMi;
  final String kaydedenUserId;
  final String? kaydedenAd;
  final DateTime createdAt;

  /// Arac su an iceride mi (acik gecis).
  bool get acik => cikisZamani == null;

  factory VehiclePass.fromJson(Map<String, dynamic> json) => VehiclePass(
    id: json['id'] as String? ?? '',
    plaka: json['plaka'] as String? ?? '',
    aracTanim: json['arac_tanim'] as String?,
    girisZamani:
        DateTime.tryParse(json['giris_zamani'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    cikisZamani: DateTime.tryParse(json['cikis_zamani'] as String? ?? ''),
    unitId: json['unit_id'] as String?,
    unitNo: json['unit_no'] as String?,
    ziyaretciMi: json['ziyaretci_mi'] as bool? ?? false,
    kaydedenUserId: json['kaydeden_user_id'] as String? ?? '',
    kaydedenAd: json['kaydeden_ad'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

/// `POST /vehicle-passes` govdesi.
///
/// Daire referansi OPSIYONEL ve TEK: `unitNo` verilirse gonderilir, yoksa
/// arac daireye bagli degildir. (Sozlesme `unit_id` VEYA `unit_no` kabul
/// eder; ikisi birlikte 422. Mobil formda numara girildigi icin yalniz
/// `unit_no` gonderilir — belirsizlik dogmaz.)
class VehiclePassDraft {
  const VehiclePassDraft({
    required this.plaka,
    this.aracTanim,
    this.unitNo,
    this.ziyaretciMi = false,
  });

  final String plaka;
  final String? aracTanim;
  final String? unitNo;
  final bool ziyaretciMi;

  Map<String, dynamic> toJson() => {
    'plaka': plaka,
    if (aracTanim != null && aracTanim!.isNotEmpty) 'arac_tanim': aracTanim,
    if (unitNo != null && unitNo!.isNotEmpty) 'unit_no': unitNo,
    'ziyaretci_mi': ziyaretciMi,
  };
}

/// Liste suzgeci — sunucunun `?acik=` parametresinin istemci aynasi.
///
/// KIMLIK / METIN AYRIMI (README §15): enum GORUNEN METIN TASIMAZ; etiket
/// cizim aninda cozulur.
enum GecisSuzgeci {
  tumu(null),
  iceride(true),
  cikmis(false);

  const GecisSuzgeci(this.acik);

  /// `?acik=` sorgu degeri; `tumu` icin parametre HIC gonderilmez.
  final bool? acik;
}
