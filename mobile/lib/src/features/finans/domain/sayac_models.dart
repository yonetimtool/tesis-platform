/// (P206 §4.5) Sayac okuma modelleri.
library;

class AnaSayac {
  const AnaSayac({required this.id, required this.ad, required this.tip});

  final String id;
  final String ad;
  final String tip;

  factory AnaSayac.fromJson(Map<String, dynamic> j) => AnaSayac(
        id: j['id'] as String,
        ad: (j['ad'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
      );
}

class BolumSayaci {
  const BolumSayaci({
    required this.id,
    required this.unitId,
    this.unitNo,
    this.ilkOkuma,
  });

  final String id;
  final String unitId;
  final String? unitNo;

  /// Onceki okuma — sahada girilen deger bunun ALTINDA olamaz.
  final double? ilkOkuma;

  factory BolumSayaci.fromJson(Map<String, dynamic> j) => BolumSayaci(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        unitNo: j['unit_no'] as String?,
        ilkOkuma: (j['ilk_okuma'] as num?)?.toDouble(),
      );
}

class GiderTuruBasit {
  const GiderTuruBasit({required this.id, required this.ad});

  final String id;
  final String ad;

  factory GiderTuruBasit.fromJson(Map<String, dynamic> j) => GiderTuruBasit(
        id: j['id'] as String,
        ad: (j['ad'] as String?) ?? '',
      );
}
