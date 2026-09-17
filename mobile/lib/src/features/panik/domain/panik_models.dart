/// (P240 §1) Panik alarmi modelleri.
library;

/// Tetiklenebilecek alarm tipleri — sunucudaki `TETIKLEYEBILIR` AYNASI.
enum PanikTip { sakin, guvenlik, yoneticiAnons }

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
  });

  final String userId;
  final String ad;
  final String rol;
  final DateTime? goruldu;
  final DateTime? mudahale;

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

  /// "A 12" / kontrol noktasi adi / bos.
  String get yer {
    if (daireNo != null && daireNo!.isNotEmpty) {
      return '${blok ?? ''} $daireNo'.trim();
    }
    return checkpointAd ?? '';
  }

  bool get acik => durum == 'acik' || durum == 'mudahale';

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
      );
}
