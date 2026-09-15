/// Anket (P38) — domain modelleri. `contracts/openapi.yaml`: AnketOut.
library;

class AnketSecenek {
  const AnketSecenek({required this.id, required this.metin, this.oy});

  final String id;
  final String metin;

  /// Oy sayisi. ACIK ankette SUNUCU null doner (surusel etki): guncel
  /// dagilimi gostermek sonraki oy verenleri etkilerdi.
  final int? oy;

  factory AnketSecenek.fromJson(Map<String, dynamic> j) => AnketSecenek(
        id: j['id'] as String,
        metin: j['metin'] as String,
        oy: (j['oy'] as num?)?.toInt(),
      );
}

class Anket {
  const Anket({
    required this.id,
    required this.baslik,
    required this.acik,
    required this.secenekler,
    this.aciklama,
    this.oyVerdim,
    this.toplamOy,
    this.gorselUrl,
    this.baslangicAt,
    this.kapanisAt,
    this.hedefRoller = const [],
    this.hedefSakinTipi,
    this.anonim = false,
    this.hedefKisi,
    this.aktif = true,
  });

  final String id;
  final String baslik;
  final String? aciklama;

  /// Oy almaya acik mi (aktif + kapanis gecmemis).
  final bool acik;

  /// Bu kisi oy verdi mi. Public (kimliksiz) yanitta null.
  final bool? oyVerdim;

  /// Toplam oy — sonuc gorunur degilse null.
  final int? toplamOy;

  final List<AnketSecenek> secenekler;

  /// (P237 §3) Gorsel — presigned okuma adresi.
  final String? gorselUrl;
  final DateTime? baslangicAt;
  final DateTime? kapanisAt;

  /// HEDEF KITLE — bos = herkes.
  final List<String> hedefRoller;
  final String? hedefSakinTipi;

  /// ANONIM MI — SONRADAN DEGISTIRILEMEZ (veritabani kilidi).
  ///
  /// Ekran bunu OY VERMEDEN ONCE gosterir: anonim OLMAYAN ankette
  /// kullanici, kimliginin yonetime gorunecegini bilerek oy vermeli
  /// (KVKK aydinlatmasi).
  final bool anonim;

  /// Katilim oraninin PAYDASI — yalniz yonetime gelir, sakine null.
  final int? hedefKisi;

  /// Anket KAPATILMIS mi (`aktif=false`). `acik`tan AYRI: `acik` tarih
  /// kapisini da icerir; "kapat" dugmesi yalniz HENUZ KAPATILMAMIS
  /// ankette anlamli.
  final bool aktif;

  /// Katilim orani (%). Payda yoksa null — UYDURMA yuzde uretilmez.
  int? get katilimYuzde {
    final h = hedefKisi;
    final o = toplamOy;
    if (h == null || h <= 0 || o == null) return null;
    return ((o / h) * 100).round();
  }

  /// Oy verilebilir mi: ACIK ve HENUZ oy vermemis.
  ///
  /// Iki kosulu ayri ayri sormak yerine tek yerde: ekran ikisini de
  /// unutmadan uygulasin (oy DEGISTIRILEMEZ — sunucu 409 doner).
  bool get oyVerilebilir => acik && oyVerdim != true;

  /// Sonuc gosterilebilir mi (sunucu sayilari doldurduysa).
  bool get sonucVar => toplamOy != null;

  factory Anket.fromJson(Map<String, dynamic> j) => Anket(
        id: j['id'] as String,
        baslik: j['baslik'] as String,
        aciklama: j['aciklama'] as String?,
        acik: j['acik'] as bool? ?? false,
        oyVerdim: j['oy_verdim'] as bool?,
        toplamOy: (j['toplam_oy'] as num?)?.toInt(),
        gorselUrl: j['gorsel_url'] as String?,
        baslangicAt: j['baslangic_at'] == null
            ? null
            : DateTime.parse(j['baslangic_at'] as String).toUtc(),
        kapanisAt: j['kapanis_at'] == null
            ? null
            : DateTime.parse(j['kapanis_at'] as String).toUtc(),
        hedefRoller: [
          for (final r in (j['hedef_roller'] as List? ?? const []))
            r as String,
        ],
        hedefSakinTipi: j['hedef_sakin_tipi'] as String?,
        anonim: j['anonim'] as bool? ?? false,
        aktif: j['aktif'] as bool? ?? true,
        hedefKisi: (j['hedef_kisi'] as num?)?.toInt(),
        secenekler: [
          for (final s in (j['secenekler'] as List? ?? const []))
            AnketSecenek.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// (P237 §3) Yeni anket govdesi — MOBILDE DE OLUSTURULABILIR.
///
/// P38'de mobil BILEREK salt-okumaydi ("olusturma YONETIM isidir ve
/// panele"). P235'te yazilan KALICI PARITE KURALI bunu gecersiz kilar:
/// bir ozellik iki yuzeyde de olmali. Yetki yine sunucuda (admin +
/// yonetici); mobilde formu gostermek yalniz UX kapisi.
class AnketTaslak {
  const AnketTaslak({
    required this.baslik,
    required this.maddeler,
    this.aciklama,
    this.gorselKey,
    this.baslangicAt,
    this.kapanisAt,
    this.hedefRoller = const [],
    this.hedefSakinTipi,
    this.anonim = false,
  });

  final String baslik;
  final List<String> maddeler;
  final String? aciklama;
  final String? gorselKey;
  final DateTime? baslangicAt;
  final DateTime? kapanisAt;
  final List<String> hedefRoller;
  final String? hedefSakinTipi;

  /// KAYDEDILDIKTEN SONRA DEGISTIRILEMEZ (sunucu + veritabani kilidi).
  final bool anonim;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'aciklama': aciklama,
        'gorsel_key': gorselKey,
        'baslangic_at': baslangicAt?.toUtc().toIso8601String(),
        'kapanis_at': kapanisAt?.toUtc().toIso8601String(),
        'secenekler': [
          for (var i = 0; i < maddeler.length; i++)
            {'metin': maddeler[i], 'sira': i},
        ],
        'hedef_roller': hedefRoller,
        'hedef_sakin_tipi': hedefSakinTipi,
        'anonim': anonim,
      };
}


/// (P237 §3) KIM NEYE OY VERDI — ADLI ankette.
class AnketOyKim {
  const AnketOyKim({
    required this.userId,
    required this.secenekId,
    required this.secenekMetin,
    required this.createdAt,
    this.ad,
  });

  final String userId;
  final String? ad;
  final String secenekId;
  final String secenekMetin;
  final DateTime createdAt;

  factory AnketOyKim.fromJson(Map<String, dynamic> j) => AnketOyKim(
        userId: j['user_id'] as String? ?? '',
        ad: j['ad'] as String?,
        secenekId: j['secenek_id'] as String? ?? '',
        secenekMetin: j['secenek_metin'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String).toUtc(),
      );
}
