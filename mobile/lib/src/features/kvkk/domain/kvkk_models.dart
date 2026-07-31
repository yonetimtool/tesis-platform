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
class KvkkMetin {
  const KvkkMetin({
    required this.id,
    required this.surum,
    required this.baslik,
    required this.govde,
  });

  final String id;
  final int surum;
  final String baslik;
  final String govde;

  factory KvkkMetin.fromJson(Map<String, dynamic> j) => KvkkMetin(
        id: j['id'] as String,
        surum: (j['surum'] as num).toInt(),
        baslik: j['baslik'] as String,
        govde: j['govde'] as String,
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
