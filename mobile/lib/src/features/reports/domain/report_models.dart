/// Aylik rapor domain modelleri + SAF yardimcilar (birim testli).
///
/// Kaynak uclar (hepsi yonetici'ye acik — auth.md §4):
///   * `GET /patrol-windows?baslangic&bitis`   → ozet (filtrelenmis TUM kume)
///   * `GET /task-completions?baslangic&bitis` → ozet + son tamamlamalar
///   * `GET /dues/assessments|payments?donem`  → aidat tahakkuk/tahsilat
library;

/// Ay siniri: [baslangic] dahil, [bitis] haric (yari-acik) — cihaz yerel
/// saatiyle ay basi/sonu alinir, sorguya UTC gonderilir (tesis TR saatinde;
/// cihaz da oyle varsayilir — tenant timezone'a gore raporlama panel isi).
({DateTime baslangic, DateTime bitis}) ayAralik(int yil, int ay) {
  final baslangic = DateTime(yil, ay, 1);
  final bitis = ay == 12 ? DateTime(yil + 1, 1, 1) : DateTime(yil, ay + 1, 1);
  return (baslangic: baslangic.toUtc(), bitis: bitis.toUtc());
}

/// Aidat donem anahtari: 'YYYY-MM' (backend `donem` filtresi bu bicimi bekler).
String donemStr(int yil, int ay) => '$yil-${ay.toString().padLeft(2, '0')}';

// AY ADI ve PARA BICIMI burada DEGIL: tur 10'da ikisi de `core/i18n/l10n.dart`
// icindeki tek kaynaga tasindi (`ayAdi` + `tlSonEkli`). Eskiden bu dosyada TR
// sabit bir ay dizisi ve `kurusToTl` (para gruplamasinin UCUNCU uygulamasi)
// duruyordu; baslik `l10n.raporAyBaslik(ayAdi(ay, dil), '$yil')` ile kurulur.

/// Kategori bazli tamamlanma sayimi (GorevOzet kalemi).
///
/// KIMLIK / METIN AYRIMI (README §15): `kategoriAd` NULL olabilir (kategorisiz);
/// TR sabit "Diğer" burada DEGIL, cizim katmanindadir.
class KategoriSayi {
  const KategoriSayi({this.kategoriAd, required this.sayi});

  /// null = kategorisiz; gorunen ad cizim aninda `l10n.gorevKategoriDiger`
  /// ile yazilir (tur 3'teki `taskKategoriStyle` emsali — domain TR sabit
  /// "Diğer" tasimaz).
  final String? kategoriAd;
  final int sayi;

  factory KategoriSayi.fromJson(Map<String, dynamic> json) => KategoriSayi(
        kategoriAd: json['kategori_ad'] as String?,
        sayi: (json['sayi'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /task-completions` → `ozet` (filtrelenmis TUM kume uzerinden).
/// Sabit tip kirilimi kaldirildi; KATEGORI bazli sayim (null = kategorisiz).
class GorevOzet {
  const GorevOzet({this.toplam = 0, this.kalemler = const []});

  final int toplam;
  final List<KategoriSayi> kalemler;

  factory GorevOzet.fromJson(Map<String, dynamic> json) => GorevOzet(
        toplam: (json['toplam'] as num?)?.toInt() ?? 0,
        kalemler: [
          for (final k in (json['kalemler'] as List? ?? const []))
            if (k is Map) KategoriSayi.fromJson(Map<String, dynamic>.from(k)),
        ],
      );
}

/// `GET /task-completions` liste ogesi — rapordaki "son tamamlamalar".
class SonTamamlama {
  const SonTamamlama({
    required this.id,
    this.kategoriAd,
    required this.tamamlanmaZamani,
    this.taskAdi,
    this.fotoVar = false,
    this.nfcDogrulandi = false,
  });

  final String id;

  /// null = kategorisiz (bkz. [KategoriSayi.kategoriAd]).
  final String? kategoriAd;
  final String? taskAdi;
  final DateTime tamamlanmaZamani;
  final bool fotoVar;
  final bool nfcDogrulandi;

  factory SonTamamlama.fromJson(Map<String, dynamic> json) => SonTamamlama(
        id: json['id'] as String? ?? '',
        kategoriAd: json['kategori_ad'] as String?,
        taskAdi: json['task_adi'] as String?,
        tamamlanmaZamani:
            DateTime.tryParse(json['tamamlanma_zamani'] as String? ?? '')
                    ?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        fotoVar: json['foto_var'] as bool? ?? false,
        nfcDogrulandi: json['nfc_dogrulandi'] as bool? ?? false,
      );
}

/// Aidat aylik ozeti — tahakkuk/tahsilat listelerinden SAF hesap.
class AidatOzet {
  const AidatOzet({
    this.tahakkukKurus = 0,
    this.tahakkukAdet = 0,
    this.tahsilatKurus = 0,
    this.tahsilatAdet = 0,
  });

  final int tahakkukKurus;
  final int tahakkukAdet;

  /// Yalnizca durum='basarili' odemeler (bekliyor/iptal sayilmaz).
  final int tahsilatKurus;
  final int tahsilatAdet;

  int get bakiyeKurus => tahakkukKurus - tahsilatKurus;

  /// 0-100 arasi tahsilat orani; tahakkuk yoksa null (oran anlamsiz).
  int? get tahsilatYuzde => tahakkukKurus <= 0
      ? null
      : (tahsilatKurus * 100 ~/ tahakkukKurus).clamp(0, 100);
}

/// Sayfalari toplanmis tahakkuk/odeme listelerinden aylik aidat ozeti.
/// Odemede yalnizca `durum == 'basarili'` sayilir (webhook'la kesinlesen).
AidatOzet aidatOzet({
  required List<Map<String, dynamic>> assessments,
  required List<Map<String, dynamic>> payments,
}) {
  var tahakkuk = 0, tahsilat = 0, tahsilatAdet = 0;
  for (final a in assessments) {
    tahakkuk += (a['tutar_kurus'] as num?)?.toInt() ?? 0;
  }
  for (final p in payments) {
    if (p['durum'] == 'basarili') {
      tahsilat += (p['tutar_kurus'] as num?)?.toInt() ?? 0;
      tahsilatAdet++;
    }
  }
  return AidatOzet(
    tahakkukKurus: tahakkuk,
    tahakkukAdet: assessments.length,
    tahsilatKurus: tahsilat,
    tahsilatAdet: tahsilatAdet,
  );
}

/// Bir ayin tum rapor verisi (uc uctan derlenir).
class AylikRapor {
  const AylikRapor({
    required this.yil,
    required this.ay,
    required this.devriyeToplam,
    required this.devriyeTamamlandi,
    required this.devriyeKacirildi,
    required this.gorev,
    required this.sonTamamlamalar,
    required this.aidat,
  });

  final int yil;
  final int ay;

  /// `GET /patrol-windows` ozeti (ay araligina filtreli).
  final int devriyeToplam;
  final int devriyeTamamlandi;
  final int devriyeKacirildi;

  final GorevOzet gorev;
  final List<SonTamamlama> sonTamamlamalar;
  final AidatOzet aidat;

  /// 0-100 devriye tamamlanma orani; pencere yoksa null.
  int? get devriyeYuzde => devriyeToplam <= 0
      ? null
      : (devriyeTamamlandi * 100 ~/ devriyeToplam).clamp(0, 100);
}
