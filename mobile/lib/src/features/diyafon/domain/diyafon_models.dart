/// (P240 §2) Diyafon modelleri.
library;

class DiyafonYetenek {
  const DiyafonYetenek({
    required this.metinAnons,
    required this.sesliAnons,
    required this.kapiAc,
    required this.zilCal,
  });

  final bool metinAnons;

  /// HICBIR yontemde true DONMEZ: bu surum medya yigini icermiyor.
  /// Arayuz bunu ACIKCA yazar — "neden ses gelmiyor" sorusu sahada
  /// degil SECIM ANINDA yanitlanmali.
  final bool sesliAnons;
  final bool kapiAc;
  final bool zilCal;

  factory DiyafonYetenek.fromJson(Map<String, dynamic> j) => DiyafonYetenek(
        metinAnons: j['metin_anons'] as bool? ?? false,
        sesliAnons: j['sesli_anons'] as bool? ?? false,
        kapiAc: j['kapi_ac'] as bool? ?? false,
        zilCal: j['zil_cal'] as bool? ?? false,
      );
}

class Diyafon {
  const Diyafon({
    required this.id,
    required this.ad,
    required this.yontem,
    required this.host,
    required this.aktif,
    required this.yetenekler,
    this.port,
    this.kullanici,
    this.sifreSet = false,
    this.hedef,
    this.zilYolu,
    this.kapiYolu,
    this.saglik = 'bilinmiyor',
    this.sonBasariliAt,
    this.sonHataKod,
  });

  final String id;
  final String ad;

  /// `sip` | `sip_kopru` | `kuru_kontak`
  final String yontem;
  final String host;
  final int? port;
  final String? kullanici;

  /// Sifrenin VARLIGI; sirrin KENDISI gelmez (write-only).
  final bool sifreSet;
  final String? hedef;
  final String? zilYolu;
  final String? kapiYolu;
  final bool aktif;
  final String saglik;
  final DateTime? sonBasariliAt;
  final String? sonHataKod;
  final DiyafonYetenek yetenekler;

  factory Diyafon.fromJson(Map<String, dynamic> j) => Diyafon(
        id: j['id'] as String,
        ad: j['ad'] as String? ?? '',
        yontem: j['yontem'] as String? ?? 'sip',
        host: j['host'] as String? ?? '',
        port: (j['port'] as num?)?.toInt(),
        kullanici: j['kullanici'] as String?,
        sifreSet: j['sifre_set'] as bool? ?? false,
        hedef: j['hedef'] as String?,
        zilYolu: j['zil_yolu'] as String?,
        kapiYolu: j['kapi_yolu'] as String?,
        aktif: j['aktif'] as bool? ?? true,
        saglik: j['saglik'] as String? ?? 'bilinmiyor',
        sonBasariliAt: j['son_basarili_at'] == null
            ? null
            : DateTime.parse(j['son_basarili_at'] as String),
        sonHataKod: j['son_hata_kod'] as String?,
        yetenekler: DiyafonYetenek.fromJson(
          Map<String, dynamic>.from((j['yetenekler'] as Map?) ?? const {}),
        ),
      );
}

/// Olusturma/guncelleme govdesi. `sifre` YALNIZ doluysa gonderilir —
/// bos birakmak "degistirme" demektir, "sil" degil.
class DiyafonTaslak {
  const DiyafonTaslak({
    required this.ad,
    required this.yontem,
    required this.host,
    this.port,
    this.kullanici,
    this.sifre,
    this.hedef,
    this.zilYolu,
    this.kapiYolu,
  });

  final String ad;
  final String yontem;
  final String host;
  final int? port;
  final String? kullanici;
  final String? sifre;
  final String? hedef;
  final String? zilYolu;
  final String? kapiYolu;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'yontem': yontem,
        'host': host,
        'port': port,
        'kullanici': kullanici,
        if (sifre != null && sifre!.isNotEmpty) 'sifre': sifre,
        'hedef': hedef,
        'zil_yolu': zilYolu,
        'kapi_yolu': kapiYolu,
      };
}
