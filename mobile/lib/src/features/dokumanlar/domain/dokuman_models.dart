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

/// (P253 A1) YONETIM gorunumu — `GET /dokumanlar` (admin + yonetici).
///
/// Sakin modelinden AYRI: sakin ucu `sakine_acik` tasimaz ve tasimamali
/// (yukarida). Yonetim ise tam bu alani DEGISTIREN taraftir.
class YonetimDokumani {
  const YonetimDokumani({
    required this.id,
    required this.ad,
    required this.createdAt,
    required this.sakineAcik,
    this.boyutBayt,
    this.aciklama,
    this.icerikTipi,
    this.yukleyenAd,
  });

  final String id;
  final String ad;
  final DateTime createdAt;
  final bool sakineAcik;
  final int? boyutBayt;
  final String? aciklama;
  final String? icerikTipi;
  final String? yukleyenAd;

  factory YonetimDokumani.fromJson(Map<String, dynamic> json) => YonetimDokumani(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        sakineAcik: json['sakine_acik'] as bool? ?? false,
        boyutBayt: (json['boyut_bayt'] as num?)?.toInt(),
        aciklama: json['aciklama'] as String?,
        icerikTipi: json['icerik_tipi'] as String?,
        yukleyenAd: json['yukleyen_ad'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// Yonetim indirme baglantisi (`GET /dokumanlar/{id}/indir`).
class DokumanBaglantisi {
  const DokumanBaglantisi({required this.url, this.dosyaAdi});
  final String url;
  final String? dosyaAdi;
}

/// Yuklenecek dosya — telefonda secilen foto (baytlar + tur + ad).
class YuklenecekDosya {
  const YuklenecekDosya({
    required this.baytlar,
    required this.icerikTipi,
    required this.dosyaAdi,
  });
  final List<int> baytlar;
  final String icerikTipi;
  final String dosyaAdi;
}

/// Turu bilinmeyen dosyanin paylasim turu.
const dokumanVarsayilanTur = 'application/octet-stream';

/// Sunucunun CHECK siniri (migration 0022) — istemci erken soyler.
const dokumanAzamiBayt = 26214400;
