/// KVKK aydinlatma + onay + pazarlama izinleri (P36) — domain modelleri.
///
/// `contracts/openapi.yaml`: KvkkDurumOut / KvkkMetinOut / PazarlamaTercihleri.
library;

/// Kullanicinin onay durumu — ONAY KAPISI bunun uzerine kurulur.
class KvkkDurum {
  const KvkkDurum({
    required this.metinVar,
    required this.onayGerekli,
    this.guncelSurum,
    this.onayladigiSurum,
  });

  /// Tenant henuz metin yayinlamadiysa false. Metinsiz bir kapi,
  /// kullaniciya OKUMADAN onaylatmak olurdu — bu yuzden kapi kurulmaz.
  final bool metinVar;

  /// true → istemci onay kapisini acar. Surum artinca yeniden true olur.
  final bool onayGerekli;

  final int? guncelSurum;
  final int? onayladigiSurum;

  factory KvkkDurum.fromJson(Map<String, dynamic> j) => KvkkDurum(
        metinVar: j['metin_var'] as bool? ?? false,
        onayGerekli: j['onay_gerekli'] as bool? ?? false,
        guncelSurum: (j['guncel_surum'] as num?)?.toInt(),
        onayladigiSurum: (j['onayladigi_surum'] as num?)?.toInt(),
      );

  /// Ag/uc hatasinda kullanilan GUVENLI varsayilan: kapi ACILMAZ.
  ///
  /// Ters yon (hatada kapiyi acmak) kullaniciyi, metni getiremeyen bir
  /// ekranda kilitlerdi — okuyamadigi bir metni onaylayamaz ve uygulamaya
  /// giremezdi. Riza denetimi zaten GONDERIM UCUNDA (sunucuda) yapiliyor;
  /// kapi UX'tir.
  static const kapaliVarsayilan =
      KvkkDurum(metinVar: false, onayGerekli: false);
}

/// Yayinlanmis aydinlatma metni (tenant icerigi — orijinal dil kurali).
/// (P168 §5) Yasal metin TURLERI — sunucudaki `kvkk_metin_tur` enum'uyla
/// BIREBIR. Sira brief'in sirasi.
///
/// TUR BASINA AYRI SURUM SERISI: gizlilik politikasi yayinlamak
/// aydinlatma metninin numarasini atlatmaz. Onay da tur basina tutulur —
/// biri otekini onaylamis SAYILMAZ.
enum KvkkTur {
  aydinlatma('aydinlatma'),
  acikRiza('acik_riza'),
  gizlilik('gizlilik'),
  kullanimKosullari('kullanim_kosullari'),
  cerez('cerez');

  const KvkkTur(this.kod);

  /// Sunucunun bekledigi deger.
  final String kod;

  static KvkkTur coz(String? kod) => KvkkTur.values.firstWhere(
        (t) => t.kod == kod,
        // BILINMEYEN TUR AYDINLATMAYA DUSER: sunucu bir gun altinci bir
        // tur eklerse mobil COKMEZ, bilinen bir metni gosterir. Istisna
        // firlatmak, guncellenmemis bir uygulamayi tamamen kilitlerdi.
        orElse: () => KvkkTur.aydinlatma,
      );
}

class KvkkMetin {
  const KvkkMetin({
    required this.id,
    required this.tur,
    required this.surum,
    required this.baslik,
    required this.govde,
    this.yururlukte = false,
  });

  final String id;
  final KvkkTur tur;
  final int surum;
  final String baslik;
  final String govde;

  /// (P168 §5) Sunucudan TURETILMIS gelir (tur basina en yuksek surum);
  /// istemci kendi hesaplamaz — iki yerde hesaplanan bir "yururlukte"
  /// bir gun ayrisirdi.
  final bool yururlukte;

  factory KvkkMetin.fromJson(Map<String, dynamic> j) => KvkkMetin(
        id: j['id'] as String,
        tur: KvkkTur.coz(j['tur'] as String?),
        surum: (j['surum'] as num).toInt(),
        baslik: j['baslik'] as String,
        govde: j['govde'] as String,
        yururlukte: j['yururlukte'] as bool? ?? false,
      );
}

/// Pazarlama izinleri — UC BAGIMSIZ kanal (tek bayrak DEGIL: kisi e-posta
/// isteyip SMS istemeyebilir). Ucu de VARSAYILAN KAPALI.
class PazarlamaTercihleri {
  const PazarlamaTercihleri({
    this.eposta = false,
    this.sms = false,
    this.arama = false,
  });

  final bool eposta;
  final bool sms;
  final bool arama;

  bool get hepsiKapali => !eposta && !sms && !arama;

  PazarlamaTercihleri copyWith({bool? eposta, bool? sms, bool? arama}) =>
      PazarlamaTercihleri(
        eposta: eposta ?? this.eposta,
        sms: sms ?? this.sms,
        arama: arama ?? this.arama,
      );

  factory PazarlamaTercihleri.fromJson(Map<String, dynamic> j) =>
      PazarlamaTercihleri(
        eposta: j['eposta'] as bool? ?? false,
        sms: j['sms'] as bool? ?? false,
        arama: j['arama'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'eposta': eposta,
        'sms': sms,
        'arama': arama,
      };
}
