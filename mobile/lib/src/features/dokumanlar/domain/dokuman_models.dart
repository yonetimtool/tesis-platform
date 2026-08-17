/// (P167 ek) SITE DOKUMANLARI — sakin gorunumu.
///
/// `contracts/openapi.yaml` `DokumanOut` semasina uyar.
///
/// SAKIN YALNIZ ACILANLARI GORUR: `tenant_dokuman` tek bir arsivdir ve
/// icinde ne oldugu sozlesmede belirli DEGIL (yonetim plani da olabilir,
/// personel sozlesmesi de). Yonetici hangi dosyanin sakine acik oldugunu
/// tek tek isaretler; suzgec SUNUCUDA (`GET /me/dokumanlar`) uygulanir.
///
/// Bu modelde `sakineAcik` ALANI YOK ve olmamali: sakin ucundan gelen her
/// kayit zaten aciktir. Alani tasimak, istemcide "acik mi" diye ikinci
/// bir suzgec yazma ihtimali dogururdu — ve o suzgec bir gun yanlis
/// yazilirsa kapali bir belge ekranda gorunurdu.
library;

class SiteDokumani {
  const SiteDokumani({
    required this.id,
    required this.ad,
    required this.createdAt,
    this.boyutBayt,
    this.aciklama,
  });

  final String id;
  final String ad;
  final DateTime createdAt;

  /// Dosya boyutu — null olabilir (eski kayitlar boyutsuz yuklendi).
  final int? boyutBayt;
  final String? aciklama;

  factory SiteDokumani.fromJson(Map<String, dynamic> json) => SiteDokumani(
    id: json['id'] as String? ?? '',
    ad: json['ad'] as String? ?? '',
    boyutBayt: (json['boyut_bayt'] as num?)?.toInt(),
    aciklama: json['aciklama'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  /// Baslik aramasi — ekranin ANLIK suzgeci (buyuk/kucuk harf duyarsiz).
  bool adEslesir(String sorgu) => ad.toLowerCase().contains(sorgu.toLowerCase());
}
