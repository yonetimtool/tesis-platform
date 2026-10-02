/// (P240 §1) Panik alarmi modelleri.
library;

/// Tetiklenebilecek alarm tipleri — sunucudaki `TETIKLEYEBILIR` AYNASI.
enum PanikTip { sakin, guvenlik, yoneticiAnons }

/// (P243 §5c) ALARMIN NE OLDUGU — `PanikTip`in yerine GECMEZ.
///
/// `tip` kimin tetikledigini ve kapsami soyler, kategori NE OLDUGUNU.
/// Her kategorinin KENDI TALIMATI var: depremde asansor yasak, gazda
/// elektrik dugmesi yasak — birbirini disliyorlar ve tek bir "acil
/// durum" cumlesi dogru davranisi kullanicinin tahminine birakirdi.
enum PanikKategori {
  deprem,
  yangin,
  gaz,
  tahliye,
  saglik,
  guvenlikTehdidi,
  diger,
}

extension PanikKategoriKimlik on PanikKategori {
  String get kimlik => switch (this) {
        PanikKategori.deprem => 'deprem',
        PanikKategori.yangin => 'yangin',
        PanikKategori.gaz => 'gaz',
        PanikKategori.tahliye => 'tahliye',
        PanikKategori.saglik => 'saglik',
        PanikKategori.guvenlikTehdidi => 'guvenlik_tehdidi',
        PanikKategori.diger => 'diger',
      };
}

extension PanikTipKimlik on PanikTip {
  /// Sunucu kimligi (`tip` alani).
  String get kimlik => switch (this) {
        PanikTip.sakin => 'sakin',
        PanikTip.guvenlik => 'guvenlik',
        PanikTip.yoneticiAnons => 'yonetici_anons',
      };
}

class PanikAlici {
  const PanikAlici({
    required this.userId,
    required this.ad,
    required this.rol,
    this.goruldu,
    this.mudahale,
    this.yanit,
  });

  final String userId;
  final String ad;
  final String rol;
  final DateTime? goruldu;
  final DateTime? mudahale;

  /// (P249 §1b) Toplu uyarida yanit: `guvende` | `yardim` | null.
  final String? yanit;

  factory PanikAlici.fromJson(Map<String, dynamic> j) => PanikAlici(
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
        goruldu: j['goruldu_at'] == null
            ? null
            : DateTime.parse(j['goruldu_at'] as String),
        mudahale: j['mudahale_at'] == null
            ? null
            : DateTime.parse(j['mudahale_at'] as String),
        yanit: j['yanit'] as String?,
      );
}

class PanikAlarm {
  const PanikAlarm({
    required this.id,
    required this.tip,
    required this.durum,
    required this.iptalPenceresiSn,
    this.olusturanAd,
    this.olusturanTelefon,
    this.daireNo,
    this.blok,
    this.checkpointAd,
    this.aciklama,
    this.mudahaleSuresiSn,
    this.son24sYanlisAlarm = 0,
    this.alicilar = const [],
    this.createdAt,
    this.kapandiAt,
    this.kapanisNotu,
    this.kategori,
    this.toplu = false,
    this.baslik = '',
    this.talimat = const [],
    this.benimYanitim,
    this.gonderildiAt,
    this.tatbikat = false,
  });

  final String id;
  final String tip;

  /// `beklemede` | `acik` | `mudahale` | `kapandi` | `iptal` | `yanlis_alarm`
  final String durum;

  /// Geri sayimin SURESI — SUNUCUDAN gelir.
  ///
  /// Sabiti istemciye gommek, sunucuda degisince iki tarafin sessizce
  /// ayrismasi demekti (kullanici 5 sn sanip 3 sn'de gonderilirdi).
  final int iptalPenceresiSn;

  final String? olusturanAd;
  final String? olusturanTelefon;
  final String? daireNo;
  final String? blok;
  final String? checkpointAd;
  final String? aciklama;
  final int? mudahaleSuresiSn;
  final int son24sYanlisAlarm;
  final List<PanikAlici> alicilar;
  final DateTime? createdAt;
  final DateTime? kapandiAt;
  final String? kapanisNotu;

  /// (P249 §1) KATEGORI — P243'te sunucu donduruyordu ama bu model
  /// OKUMUYORDU; alici ekrani bu yuzden deprem ile saglik acilini ayni
  /// sabit sablonla ciziyordu. `null` = kategorisiz (P240 donemi).
  final String? kategori;

  /// Toplu uyari (deprem/yangin/gaz/tahliye) mi, yardim cagrisi mi.
  /// Sunucu karar verir: iki ayri kumeyi istemcide yeniden yazmak, bir
  /// gun ayrismalari demekti.
  final bool toplu;

  /// Istegin dilinde baslik ("DEPREM ALARMI") ve ADIM ADIM talimat —
  /// tek kaynak sunucu (`panik_talimat.py`), push basligiyla ayni metin.
  final String baslik;
  final List<String> talimat;

  /// Bu kullanicinin yaniti (`guvende` | `yardim` | null).
  final String? benimYanitim;
  final DateTime? gonderildiAt;

  /// (P249 §2) Tatbikat alarmi — ekranda ayrica "TATBIKAT" seridi.
  final bool tatbikat;

  /// "A 12" / kontrol noktasi adi / bos.
  String get yer {
    if (daireNo != null && daireNo!.isNotEmpty) {
      return '${blok ?? ''} $daireNo'.trim();
    }
    return checkpointAd ?? '';
  }

  /// (P251 §1) Sunucunun tek tanimi: sonuclanmamis her durum (iptal
  /// penceresindeki `beklemede` dahil — yonetim onu da kapatabilir).
  bool get acik =>
      durum == 'beklemede' || durum == 'acik' || durum == 'mudahale';

  factory PanikAlarm.fromJson(Map<String, dynamic> j) => PanikAlarm(
        id: j['id'] as String,
        tip: (j['tip'] as String?) ?? '',
        durum: (j['durum'] as String?) ?? '',
        iptalPenceresiSn: (j['iptal_penceresi_sn'] as num?)?.toInt() ?? 5,
        olusturanAd: j['olusturan_ad'] as String?,
        olusturanTelefon: j['olusturan_telefon'] as String?,
        daireNo: j['daire_no'] as String?,
        blok: j['blok'] as String?,
        checkpointAd: j['checkpoint_ad'] as String?,
        aciklama: j['aciklama'] as String?,
        mudahaleSuresiSn: (j['mudahale_suresi_sn'] as num?)?.toInt(),
        son24sYanlisAlarm: (j['son_24s_yanlis_alarm'] as num?)?.toInt() ?? 0,
        alicilar: ((j['alicilar'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PanikAlici.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
        kapandiAt: j['kapandi_at'] == null
            ? null
            : DateTime.parse(j['kapandi_at'] as String),
        kapanisNotu: j['kapanis_notu'] as String?,
        kategori: j['kategori'] as String?,
        toplu: (j['toplu'] as bool?) ?? false,
        baslik: (j['baslik'] as String?) ?? '',
        talimat: ((j['talimat'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        benimYanitim: j['benim_yanitim'] as String?,
        gonderildiAt: j['gonderildi_at'] == null
            ? null
            : DateTime.parse(j['gonderildi_at'] as String),
        tatbikat: (j['tatbikat'] as bool?) ?? false,
      );
}

/// (P249 §1b) Daire bazinda durumun bir kisisi.
class PanikDurumKisi {
  const PanikDurumKisi({
    required this.userId,
    required this.ad,
    required this.rol,
    this.yanit,
    this.goruldu = false,
    this.yanitSuresiSn,
  });

  final String userId;
  final String ad;
  final String rol;
  final String? yanit;
  final bool goruldu;
  final int? yanitSuresiSn;

  factory PanikDurumKisi.fromJson(Map<String, dynamic> j) => PanikDurumKisi(
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
        yanit: j['yanit'] as String?,
        goruldu: j['goruldu_at'] != null,
        yanitSuresiSn: (j['yanit_suresi_sn'] as num?)?.toInt(),
      );
}

class PanikDurumDaire {
  const PanikDurumDaire({
    this.blok,
    this.daireNo,
    required this.durum,
    required this.kisiler,
  });

  final String? blok;
  final String? daireNo;

  /// `yardim` | `yanitsiz` | `guvende` — sunucu siralar (yardim en ustte).
  final String durum;
  final List<PanikDurumKisi> kisiler;

  String get ad {
    final no = daireNo ?? '';
    final b = blok ?? '';
    return (b.isEmpty || no.startsWith(b)) ? no : '$b $no';
  }

  factory PanikDurumDaire.fromJson(Map<String, dynamic> j) => PanikDurumDaire(
        blok: j['blok'] as String?,
        daireNo: j['daire_no'] as String?,
        durum: (j['durum'] as String?) ?? 'yanitsiz',
        kisiler: ((j['kisiler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PanikDurumKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// (P249 §1b) `GET /panik/{id}/durum` — kim guvende, kim yardim istiyor,
/// kim yanit vermedi. Yalniz yonetim ve guvenlik.
class PanikDurum {
  const PanikDurum({
    required this.alici,
    required this.goruldu,
    required this.guvende,
    required this.yardim,
    required this.yanitsiz,
    this.ortalamaYanitSn,
    this.daireler = const [],
    this.personel = const [],
  });

  final int alici;
  final int goruldu;
  final int guvende;
  final int yardim;
  final int yanitsiz;
  final int? ortalamaYanitSn;
  final List<PanikDurumDaire> daireler;
  final List<PanikDurumKisi> personel;

  factory PanikDurum.fromJson(Map<String, dynamic> j) => PanikDurum(
        alici: (j['alici'] as num?)?.toInt() ?? 0,
        goruldu: (j['goruldu'] as num?)?.toInt() ?? 0,
        guvende: (j['guvende'] as num?)?.toInt() ?? 0,
        yardim: (j['yardim'] as num?)?.toInt() ?? 0,
        yanitsiz: (j['yanitsiz'] as num?)?.toInt() ?? 0,
        ortalamaYanitSn: (j['ortalama_yanit_sn'] as num?)?.toInt(),
        daireler: ((j['daireler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PanikDurumDaire.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        personel: ((j['personel'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PanikDurumKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}


/// (P251 §1) Takip ekraninin sayilari — SUNUCUDA, durumdan hesaplanir.
/// Istemci `kapandiAt` ile saymaz: iptal/yanlis alarm o damgayi yazmaz.
class PanikOzet {
  const PanikOzet({
    this.acik = 0,
    this.bugun = 0,
    this.kapanan = 0,
    this.yanlisAlarm = 0,
    this.iptal = 0,
  });
  final int acik;
  final int bugun;
  final int kapanan;
  final int yanlisAlarm;
  final int iptal;

  factory PanikOzet.fromJson(Map<String, dynamic> j) => PanikOzet(
    acik: (j['acik'] as num?)?.toInt() ?? 0,
    bugun: (j['bugun'] as num?)?.toInt() ?? 0,
    kapanan: (j['kapanan'] as num?)?.toInt() ?? 0,
    yanlisAlarm: (j['yanlis_alarm'] as num?)?.toInt() ?? 0,
    iptal: (j['iptal'] as num?)?.toInt() ?? 0,
  );
}

class PanikListe {
  const PanikListe({
    required this.items,
    required this.durumlar,
    this.ozet = const PanikOzet(),
  });
  final List<PanikAlarm> items;

  /// Sunucunun TUM durumlari (enum'dan) — suzgec bundan cizilir.
  final List<String> durumlar;
  final PanikOzet ozet;

  factory PanikListe.fromJson(Map<String, dynamic> j) => PanikListe(
    items: ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => PanikAlarm.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    durumlar: [
      for (final d in (j['durumlar'] as List?) ?? const []) '$d',
    ],
    ozet: j['ozet'] is Map
        ? PanikOzet.fromJson(Map<String, dynamic>.from(j['ozet'] as Map))
        : const PanikOzet(),
  );
}
