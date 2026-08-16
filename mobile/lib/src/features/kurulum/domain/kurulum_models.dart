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
  });

  /// Sunucunun adim kimligi (`blok`, `daire`, `aidat`...). METIN DEGIL
  /// KIMLIK: gorunen ad cizim aninda l10n'dan cozulur.
  final String kod;

  /// Adimin urettigi kayit sayisi (orn. kac blok). Tamamlanan adimda
  /// "3 kayit" diye gosterilir — "bitti" demekten daha cok sey soyler.
  final int sayi;
  final bool tamam;
  final bool atlandi;

  factory KurulumAdim.fromJson(Map<String, dynamic> json) => KurulumAdim(
    kod: json['kod'] as String,
    sayi: (json['sayi'] as num?)?.toInt() ?? 0,
    tamam: json['tamam'] as bool? ?? false,
    atlandi: json['atlandi'] as bool? ?? false,
  );
}

/// Sihirbazin butun durumu.
class KurulumDurum {
  const KurulumDurum({
    required this.adimlar,
    required this.toplam,
    required this.gecilen,
  });

  final List<KurulumAdim> adimlar;
  final int toplam;

  /// Tamamlanan + ATLANAN adim sayisi. Atlayani da saymak sunucunun
  /// karari: aksi hâlde bilincli atlayan bir tesis %100'e asla ulasamaz.
  final int gecilen;

  bool get bitti => toplam > 0 && gecilen >= toplam;

  factory KurulumDurum.fromJson(Map<String, dynamic> json) => KurulumDurum(
    adimlar: [
      for (final m in (json['adimlar'] as List? ?? const []).whereType<Map>())
        KurulumAdim.fromJson(Map<String, dynamic>.from(m)),
    ],
    toplam: (json['toplam'] as num?)?.toInt() ?? 0,
    gecilen: (json['gecilen'] as num?)?.toInt() ?? 0,
  );
}
