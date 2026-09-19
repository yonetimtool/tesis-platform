/// (P166 §8.2) KURULUM SIHIRBAZI — mobil model.
///
/// Web ile AYNI UCU (`GET/PATCH /kurulum`) okur. Adim listesi, tamamlanma
/// ve atlanma SUNUCUDA hesaplanir (`routers/kurulum.py`); istemci hicbirini
/// yeniden turetmez — turetseydi web ile mobil ayni tesis icin farkli
/// ilerleme gosterebilirdi.
library;

/// Tek bir kurulum adimi.
class KurulumAdim {
  const KurulumAdim({
    required this.kod,
    required this.sayi,
    required this.tamam,
    required this.atlandi,
    this.asgari = false,
  });

  /// Sunucunun adim kimligi (`blok`, `daire`, `aidat`...). METIN DEGIL
  /// KIMLIK: gorunen ad cizim aninda l10n'dan cozulur.
  final String kod;

  /// Adimin urettigi kayit sayisi (orn. kac blok). Tamamlanan adimda
  /// "3 kayit" diye gosterilir — "bitti" demekten daha cok sey soyler.
  final int sayi;
  final bool tamam;
  final bool atlandi;

  /// (P243 §6a) Adim ASGARI CALISIR KURULUMUN parcasi mi (blok/daire).
  ///
  /// `zorunlu`dan DARDIR ve ayrim bilincli: "zorunlu" eninde sonunda
  /// gerekir, "asgari" olmadan tesis HIC calismaz. Ekran ikisini ayri
  /// bolumde cizer — eski tek liste, yeni yoneticiye duyuru yapmak icin
  /// once muhasebe kurmasi gerektigini sandiriyordu.
  final bool asgari;

  factory KurulumAdim.fromJson(Map<String, dynamic> json) => KurulumAdim(
    kod: json['kod'] as String,
    sayi: (json['sayi'] as num?)?.toInt() ?? 0,
    tamam: json['tamam'] as bool? ?? false,
    atlandi: json['atlandi'] as bool? ?? false,
    asgari: json['asgari'] as bool? ?? false,
  );
}

/// Sihirbazin butun durumu.
class KurulumDurum {
  const KurulumDurum({
    required this.adimlar,
    required this.toplam,
    required this.gecilen,
    this.calisir = true,
    this.asgariToplam = 0,
    this.asgariEksikler = const [],
  });

  final List<KurulumAdim> adimlar;
  final int toplam;

  /// Tamamlanan + ATLANAN adim sayisi. Atlayani da saymak sunucunun
  /// karari: aksi hâlde bilincli atlayan bir tesis %100'e asla ulasamaz.
  final int gecilen;

  /// (P243 §6a) Tesis CALISIR hâlde mi — olcut ASGARI kurulumdur.
  final bool calisir;

  /// Asgari kurulumun adim sayisi. `0` = ESKI SUNUCU: o durumda asgari
  /// bolumu HIC cizilmez ("0/0 hazır" anlamsiz bir sayac olurdu).
  final int asgariToplam;
  final List<String> asgariEksikler;

  bool get bitti => toplam > 0 && gecilen >= toplam;

  factory KurulumDurum.fromJson(Map<String, dynamic> json) => KurulumDurum(
    adimlar: [
      for (final m in (json['adimlar'] as List? ?? const []).whereType<Map>())
        KurulumAdim.fromJson(Map<String, dynamic>.from(m)),
    ],
    toplam: (json['toplam'] as num?)?.toInt() ?? 0,
    gecilen: (json['gecilen'] as num?)?.toInt() ?? 0,
    calisir: json['calisir'] as bool? ?? true,
    asgariToplam: (json['asgari_toplam'] as num?)?.toInt() ?? 0,
    asgariEksikler: [
      for (final k in (json['asgari_eksikler'] as List? ?? const []))
        k.toString(),
    ],
  );
}
