/// (P253 A1) TAKVIM + KISISEL HATIRLATMALAR — `contracts/openapi.yaml`
/// `HatirlatmaOut` / `TakvimOgesi` semalarina uyar.
///
/// Hatirlatma YALNIZ SAHIBININDIR (sunucu zorlar): ayni tesisteki baska
/// bir yonetici bile gormez. Site etkinligiyle (`Etkinlik`) karistirilmaz.
library;

/// Sunucunun bildigi tekrar kurallari (sema enum'u).
const hatirlatmaTekrarlari = ['yok', 'gunluk', 'haftalik', 'aylik'];

/// Web takvimiyle AYNI renk kimlikleri (`components/pano/takvim.tsx`).
const hatirlatmaRenkleri = ['mavi', 'yesil', 'turuncu', 'kirmizi', 'mor'];

class Hatirlatma {
  const Hatirlatma({
    required this.id,
    required this.baslik,
    required this.baslangic,
    this.aciklama,
    this.bitis,
    this.renk = 'mavi',
    this.tekrar = 'yok',
  });

  final String id;
  final String baslik;
  final String? aciklama;
  final DateTime baslangic;
  final DateTime? bitis;
  final String renk;
  final String tekrar;

  factory Hatirlatma.fromJson(Map<String, dynamic> j) => Hatirlatma(
        id: j['id'] as String? ?? '',
        baslik: j['baslik'] as String? ?? '',
        aciklama: j['aciklama'] as String?,
        baslangic: DateTime.tryParse(j['baslangic'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        bitis: DateTime.tryParse(j['bitis'] as String? ?? '')?.toLocal(),
        renk: j['renk'] as String? ?? 'mavi',
        tekrar: j['tekrar'] as String? ?? 'yok',
      );
}

/// Kaydetme govdesi — ekle (tam) ve guncelle (ayni alanlar) icin.
class HatirlatmaTaslak {
  const HatirlatmaTaslak({
    required this.baslik,
    required this.baslangic,
    this.aciklama,
    this.bitis,
    this.renk = 'mavi',
    this.tekrar = 'yok',
  });

  final String baslik;
  final String? aciklama;
  final DateTime baslangic;
  final DateTime? bitis;
  final String renk;
  final String tekrar;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'aciklama': aciklama,
        'baslangic': baslangic.toUtc().toIso8601String(),
        'bitis': bitis?.toUtc().toIso8601String(),
        'renk': renk,
        'tekrar': tekrar,
      };
}

/// Takvimde cizilen TEK olay — alti kaynak sunucuda tek dile cevrilir.
class TakvimOgesi {
  const TakvimOgesi({
    required this.tip,
    required this.id,
    required this.baslik,
    required this.baslangic,
    this.bitis,
    this.renk,
  });

  /// etkinlik | devriye | aidat | gorev | rezervasyon | hatirlatma
  final String tip;
  final String id;
  final String baslik;
  final DateTime baslangic;
  final DateTime? bitis;
  final String? renk;

  bool get hatirlatma => tip == 'hatirlatma';

  factory TakvimOgesi.fromJson(Map<String, dynamic> j) => TakvimOgesi(
        tip: j['tip'] as String? ?? '',
        id: j['id'] as String? ?? '',
        baslik: j['baslik'] as String? ?? '',
        baslangic: DateTime.tryParse(j['baslangic'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        bitis: DateTime.tryParse(j['bitis'] as String? ?? '')?.toLocal(),
        renk: j['renk'] as String?,
      );
}
