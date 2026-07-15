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

/// TR ay adi ('Temmuz 2026' gibi baslik icin).
const _ayAdlari = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String ayBaslik(int yil, int ay) => '${_ayAdlari[ay - 1]} $yil';

/// 75000 kurus -> '750,00 TL' (tam sayi aritmetigi; float yok — panel
/// lib/money.ts ile ayni kural).
String kurusToTl(int kurus) {
  final neg = kurus < 0;
  final abs = kurus.abs();
  final lira = abs ~/ 100;
  final kr = (abs % 100).toString().padLeft(2, '0');
  // binlik ayirici: 1234567 -> 1.234.567
  final s = lira.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf,$kr TL';
}

/// Kategori bazli tamamlanma sayimi (GorevOzet kalemi).
class KategoriSayi {
  const KategoriSayi({required this.kategoriAd, required this.sayi});

  final String kategoriAd;
  final int sayi;

  factory KategoriSayi.fromJson(Map<String, dynamic> json) => KategoriSayi(
        kategoriAd: json['kategori_ad'] as String? ?? 'Diğer',
        sayi: (json['sayi'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /task-completions` → `ozet` (filtrelenmis TUM kume uzerinden).
/// Sabit tip kirilimi kaldirildi; KATEGORI bazli sayim (NULL kategori "Diğer").
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
    required this.kategoriAd,
    required this.tamamlanmaZamani,
    this.taskAdi,
    this.fotoVar = false,
    this.nfcDogrulandi = false,
  });

  final String id;
  final String kategoriAd;
  final String? taskAdi;
  final DateTime tamamlanmaZamani;
  final bool fotoVar;
  final bool nfcDogrulandi;

  factory SonTamamlama.fromJson(Map<String, dynamic> json) => SonTamamlama(
        id: json['id'] as String? ?? '',
        kategoriAd: json['kategori_ad'] as String? ?? 'Diğer',
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
