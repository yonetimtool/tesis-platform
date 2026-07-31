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
        secenekler: [
          for (final s in (j['secenekler'] as List? ?? const []))
            AnketSecenek.fromJson(s as Map<String, dynamic>),
        ],
      );
}
