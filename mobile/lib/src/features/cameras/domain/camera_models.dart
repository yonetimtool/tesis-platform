/// Kamera modulunun domain modelleri — `contracts/openapi.yaml` Camera /
/// CameraCreate / CameraUpdate semalarina uyar.
///
/// GORUNURLUK SUNUCUDA: `GET /cameras` rol'e gore suzulur (admin/yonetici/
/// security TUMU; resident/tesis_gorevlisi yalniz `aktif && sakin_gorebilir`).
/// Istemci bu suzgeci TEKRARLAMAZ — gelen liste dogrudur; `sakinGorebilir`
/// alani yalniz YONETIM formunda (anahtar) ve rozette kullanilir.
///
/// `oynatilabilir` SUNUCUDAN gelir: hls/mp4 -> true, rtsp -> false —
/// **AMA `restream_url` doluysa rtsp de true olur** (P17). Restream, RTSP
/// kamerayi oynatilabilir yapan HLS gecididir (Frigate/go2rtc); P15'te
/// olculdu ve gercekten oynatilabilir oldugu dogrulandi. Istemci oynatirken
/// `oynatilacakUrl` kullanir: restream varsa ONU, yoksa `streamUrl`i.
library;

/// Yayin URL'si dogrulama hatasinin TURU (metin degil — i18n icin).
enum CameraUrlHatasi {
  /// Alan bos.
  bos,

  /// hls/mp4 icin http(s):// gerekli.
  httpSemasiGerekli,

  /// rtsp icin rtsp:// gerekli.
  rtspSemasiGerekli,

  /// Adres [kCameraUrlUstSinir] karakteri asiyor (P25a). Sunucu da reddeder;
  /// istemci ONCE yakalar ki kullanici gonderip beklemesin.
  cokUzun,
}

/// Yayin adresi UST SINIRI — sunucudaki `URL_UST_SINIR` ile AYNI sayi.
/// Iki yerde durmasi bilincli: istemci sunucuya sormadan uyarabilmeli, ama
/// KARAR sunucunundur (istemci sinirsizca gonderse de 422 alir).
const int kCameraUrlUstSinir = 2048;

/// `camera_tur` enum'unun istemci aynasi.
enum CameraTur {
  hls('hls', 'HLS', 'https://... .m3u8'),
  mp4('mp4', 'MP4', 'https://... .mp4'),
  rtsp('rtsp', 'RTSP', 'rtsp://...');

  const CameraTur(this.wire, this.label, this.ornek);

  /// Backend enum degeri.
  final String wire;

  /// Secicide gorunen ad.
  final String label;

  /// URL alani ipucu.
  final String ornek;

  /// Bu turun URL'i hangi sema(lar) ile baslamali (sunucu 422 kurali).
  List<String> get semalar => this == CameraTur.rtsp
      ? const ['rtsp://']
      : const ['http://', 'https://'];

  /// Istemci bu turu NATIVE oynatabilir mi (sunucudaki `oynatilabilir` ile
  /// ayni kural — yanit alani yoksa geri dusus icin).
  bool get oynatilabilir => this != CameraTur.rtsp;

  /// Bilinmeyen/eksik deger → hls (en yaygin canli yayin turu).
  static CameraTur fromWire(String? value) {
    for (final t in CameraTur.values) {
      if (t.wire == value) return t;
    }
    return CameraTur.hls;
  }
}

class Camera {
  const Camera({
    required this.id,
    required this.ad,
    required this.streamUrl,
    this.konum,
    this.tur = CameraTur.hls,
    this.aktif = true,
    this.sakinGorebilir = false,
    this.restreamUrl,
    bool? oynatilabilir,
  }) : _oynatilabilir = oynatilabilir; // ignore: prefer_initializing_formals

  final String id;
  final String ad;

  /// Serbest konum metni (orn. "Ana Kapı - Giriş"); yoksa null.
  final String? konum;

  final String streamUrl;

  /// RTSP kamerayi oynatilabilir yapan HLS gecidi (P17); yoksa null.
  /// `streamUrl` KORUNUR — o kameranin KENDI adresidir.
  final String? restreamUrl;

  final CameraTur tur;

  /// Pasif kamera yonetimde gorunur, sakine HIC gonderilmez (sunucu suzer).
  final bool aktif;

  /// KVKK anahtari — sakin/tesis gorevlisi gorunurlugu (yonetim acar).
  final bool sakinGorebilir;

  final bool? _oynatilabilir;

  /// Sunucunun `oynatilabilir` alani; yoksa YERELDE ayni kural uygulanir
  /// (restream varsa true, yoksa ture bak) — eski sunucuya karsi geri dusus.
  bool get oynatilabilir =>
      _oynatilabilir ?? (restreamUrl != null ? true : tur.oynatilabilir);

  /// OYNATICIYA verilecek adres: restream varsa ONU, yoksa kameranin kendi
  /// adresini. Oynatici bu ayrimi bilmez — tek alan okur.
  String get oynatilacakUrl => (restreamUrl != null && restreamUrl!.isNotEmpty)
      ? restreamUrl!
      : streamUrl;

  /// Oynatilan sey bir GECIT mi (rozet/aciklama icin).
  bool get restreamUzerinden =>
      restreamUrl != null && restreamUrl!.isNotEmpty && tur == CameraTur.rtsp;

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
    id: json['id'] as String? ?? '',
    ad: json['ad'] as String? ?? '',
    konum: json['konum'] as String?,
    streamUrl: json['stream_url'] as String? ?? '',
    tur: CameraTur.fromWire(json['tur'] as String?),
    aktif: json['aktif'] as bool? ?? true,
    sakinGorebilir: json['sakin_gorebilir'] as bool? ?? false,
    restreamUrl: json['restream_url'] as String?,
    oynatilabilir: json['oynatilabilir'] as bool?,
  );
}

/// `POST /cameras` / `PATCH /cameras/{id}` govdesi (admin + yonetici).
class CameraDraft {
  const CameraDraft({
    required this.ad,
    required this.streamUrl,
    required this.tur,
    required this.aktif,
    required this.sakinGorebilir,
    this.konum,
    this.restreamUrl,
  });

  final String ad;

  /// Bos ise PATCH'te ACIK null gonderilir (konum kaldirilir).
  final String? konum;

  final String streamUrl;
  final CameraTur tur;
  final bool aktif;
  final bool sakinGorebilir;

  /// Opsiyonel HLS gecidi (P17). Bos ise gonderilmez/temizlenir.
  final String? restreamUrl;

  /// Olusturma govdesi — bos konum HIC yazilmaz (sunucu minLength 1).
  Map<String, dynamic> toCreateJson() => {
    'ad': ad,
    if (konum != null && konum!.isNotEmpty) 'konum': konum,
    'stream_url': streamUrl,
    'tur': tur.wire,
    'aktif': aktif,
    'sakin_gorebilir': sakinGorebilir,
    if (restreamUrl != null && restreamUrl!.isNotEmpty)
      'restream_url': restreamUrl,
  };

  /// Guncelleme govdesi — tum alanlar gonderilir; bos konum ACIK null
  /// (sunucu sozlesmesi: acik null alani temizler).
  Map<String, dynamic> toUpdateJson() => {
    'ad': ad,
    'konum': (konum == null || konum!.isEmpty) ? null : konum,
    'stream_url': streamUrl,
    'tur': tur.wire,
    'aktif': aktif,
    'sakin_gorebilir': sakinGorebilir,
    // ACIK null: bos birakilirsa gecit KALDIRILIR (sunucu sozlesmesi).
    'restream_url': (restreamUrl == null || restreamUrl!.isEmpty)
        ? null
        : restreamUrl,
  };

  /// Istemci tarafi URL/tur tutarlilik kontrolu — sunucudaki 422 kuralinin
  /// AYNISI (hls/mp4 -> http(s), rtsp -> rtsp://).
  ///
  /// METIN DONDURMEZ: domain katmani dil bilmez (i18n). Hata TURU doner;
  /// kullaniciya gosterilecek metni form katmani aktif dilden secer
  /// (bkz. kamera_form_sheet.dart).
  /// Restream adresi dogrulamasi — YALNIZ http(s) (sunucudaki kuralin
  /// aynisi). Bos/null gecerlidir (gecit yok demektir).
  static CameraUrlHatasi? restreamHatasi(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    if (u.length > kCameraUrlUstSinir) return CameraUrlHatasi.cokUzun;
    if (u.startsWith('http://') || u.startsWith('https://')) return null;
    return CameraUrlHatasi.httpSemasiGerekli;
  }

  static CameraUrlHatasi? urlHatasi(String url, CameraTur tur) {
    final u = url.trim();
    if (u.isEmpty) return CameraUrlHatasi.bos;
    // UZUNLUK SEMADAN ONCE: 3 KB'lik bir yapistirmada "https ile baslamali"
    // demek yaniltici olurdu — adres zaten https ile BASLIYOR olabilir.
    if (u.length > kCameraUrlUstSinir) return CameraUrlHatasi.cokUzun;
    if (tur.semalar.any(u.startsWith)) return null;
    return tur == CameraTur.rtsp
        ? CameraUrlHatasi.rtspSemasiGerekli
        : CameraUrlHatasi.httpSemasiGerekli;
  }
}
