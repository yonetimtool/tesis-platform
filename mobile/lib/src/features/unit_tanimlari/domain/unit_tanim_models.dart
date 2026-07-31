/// Bagimsiz Bolum TIP + GRUP tanimlari (P26) — `contracts/openapi.yaml`
/// `UnitTip` / `UnitGrup` semalarina uyar.
///
/// IKI AYRI KAVRAM: GRUP bolumun NE OLDUGU (Daire / Villa / Dukkan),
/// TIP buyukluk/duzen (1+0, 2+1, dubleks) + VARSAYILAN AIDAT TUTARI.
library;

/// Iki tanimin ORTAK yuzeyi — liste/secici bilesenleri tek bicimde calissin.
///
/// Ortak bir arayuz olmasaydi tip ve grup icin ayni ekranin iki kopyasi
/// yazilirdi; tek fark tipin aidat tasimasidir.
abstract class UnitTanim {
  String get id;
  String get ad;
  bool get aktif;

  /// Bu tanima bagli daire sayisi — silmeden once "kac daireyi etkiler".
  int get daireSayisi;
}

class UnitTip implements UnitTanim {
  const UnitTip({
    required this.id,
    required this.ad,
    required this.aktif,
    this.varsayilanAidatKurus,
    this.daireSayisi = 0,
  });

  @override
  final String id;
  @override
  final String ad;
  @override
  final bool aktif;
  @override
  final int daireSayisi;

  /// Varsayilan aidat, KURUS.
  ///
  /// `null` **"tanimsiz"** demektir, **0 DEGIL** — 0 gecerli bir tutardir
  /// (muaf daire) ve ikisini karistirmak P28'de sessiz sifir aidat uretirdi.
  final int? varsayilanAidatKurus;

  factory UnitTip.fromJson(Map<String, dynamic> json) => UnitTip(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        aktif: json['aktif'] as bool? ?? true,
        varsayilanAidatKurus: (json['varsayilan_aidat_kurus'] as num?)?.toInt(),
        daireSayisi: (json['daire_sayisi'] as num?)?.toInt() ?? 0,
      );
}

class UnitGrup implements UnitTanim {
  const UnitGrup({
    required this.id,
    required this.ad,
    required this.aktif,
    this.daireSayisi = 0,
  });

  @override
  final String id;
  @override
  final String ad;
  @override
  final bool aktif;
  @override
  final int daireSayisi;

  factory UnitGrup.fromJson(Map<String, dynamic> json) => UnitGrup(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        aktif: json['aktif'] as bool? ?? true,
        daireSayisi: (json['daire_sayisi'] as num?)?.toInt() ?? 0,
      );
}

/// Tanim olusturma/guncelleme govdesi.
///
/// [aidatGirildi] ile [varsayilanAidatKurus] ayrimi BILINCLIDIR: guncellemede
/// "alani gondermedim" (dokunma) ile "null gonderdim" (tutari KALDIR) ayri
/// seylerdir ve sunucu ikisini `exclude_unset` ile ayirir.
class UnitTanimDraft {
  const UnitTanimDraft({
    required this.ad,
    this.aktif,
    this.varsayilanAidatKurus,
    this.aidatGirildi = false,
  });

  final String ad;
  final bool? aktif;
  final int? varsayilanAidatKurus;
  final bool aidatGirildi;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        if (aktif != null) 'aktif': aktif,
        if (aidatGirildi) 'varsayilan_aidat_kurus': varsayilanAidatKurus,
      };
}
