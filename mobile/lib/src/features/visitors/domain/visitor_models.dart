/// Ziyaretci modulunun domain modelleri — `contracts/openapi.yaml`
/// Visitor / VisitorCreate / VisitorUpdate semalarina uyar.
///
/// Akis (urun sahibi sabit): guvenlik kaydeder -> dairenin TUM aktif
/// sakinlerine push -> ILK yanitlayan sakin onaylar/reddeder (ikinci 409) ->
/// sonuc kaydi acan guvenlige push + ekranda. RBAC (auth.md §4): KAYIT yalniz
/// security; YANIT yalniz o dairenin aktif sakini; OKUMA yonetim+guvenlik
/// tum gecmis, sakin kendi dairesi; tesis_gorevlisi erisemez.
library;

/// `visitor_durum` enum'unun istemci aynasi. GSM'e hazir: ileride arama
/// adimi eklenirse yeni deger [unknown]'a duser (eski surum COKMEZ).
enum VisitorDurum {
  bekliyor('bekliyor', 'Bekliyor'),
  onaylandi('onaylandi', 'Onaylandı'),
  reddedildi('reddedildi', 'Reddedildi'),
  unknown('unknown', 'Bilinmeyen');

  const VisitorDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  static VisitorDurum fromWire(String? value) => VisitorDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => VisitorDurum.unknown,
      );
}

class Visitor {
  const Visitor({
    required this.id,
    required this.unitId,
    required this.ziyaretciAd,
    required this.durum,
    required this.kaydedenUserId,
    required this.createdAt,
    this.unitNo,
    this.notlar,
    this.kaydedenAd,
    this.yanitlayanUserId,
    this.yanitlayanAd,
    this.yanitZamani,
  });

  final String id;
  final String unitId;

  /// Daire numarasi (sunucu join ile doldurur — liste/karti icin).
  final String? unitNo;

  final String ziyaretciAd;
  final String? notlar;
  final VisitorDurum durum;

  /// Kaydi acan guvenlik (sonuc push'unun hedefi).
  final String kaydedenUserId;
  final String? kaydedenAd;

  /// Yaniti veren sakin (ilk yanit kazanir; yanitsizsa null).
  final String? yanitlayanUserId;
  final String? yanitlayanAd;
  final DateTime? yanitZamani;

  final DateTime createdAt;

  bool get bekliyor => durum == VisitorDurum.bekliyor;

  factory Visitor.fromJson(Map<String, dynamic> json) => Visitor(
        id: json['id'] as String? ?? '',
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        ziyaretciAd: json['ziyaretci_ad'] as String? ?? '',
        notlar: json['notlar'] as String?,
        durum: VisitorDurum.fromWire(json['durum'] as String?),
        kaydedenUserId: json['kaydeden_user_id'] as String? ?? '',
        kaydedenAd: json['kaydeden_ad'] as String?,
        yanitlayanUserId: json['yanitlayan_user_id'] as String?,
        yanitlayanAd: json['yanitlayan_ad'] as String?,
        yanitZamani: json['yanit_zamani'] == null
            ? null
            : DateTime.tryParse(json['yanit_zamani'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /visitors` govdesi (yalniz guvenlik). Kapidaki guvenlik daireyi
/// NUMARASIYLA girer (unit listesine RBAC'i yok); sunucu tenant icinde
/// cozer, bulunamazsa 422.
class VisitorDraft {
  const VisitorDraft({
    required this.ziyaretciAd,
    required this.unitNo,
    this.notlar,
  });

  final String ziyaretciAd;
  final String unitNo;

  /// Opsiyonel not; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'ziyaretci_ad': ziyaretciAd,
        'unit_no': unitNo,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}
