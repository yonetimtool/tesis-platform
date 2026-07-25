/// Kamera modulunun domain modelleri — `contracts/openapi.yaml` Camera /
/// CameraCreate / CameraUpdate semalarina uyar.
///
/// GORUNURLUK SUNUCUDA: `GET /cameras` rol'e gore suzulur (admin/yonetici/
/// security TUMU; resident/tesis_gorevlisi yalniz `aktif && sakin_gorebilir`).
/// Istemci bu suzgeci TEKRARLAMAZ — gelen liste dogrudur; `sakinGorebilir`
/// alani yalniz YONETIM formunda (anahtar) ve rozette kullanilir.
///
/// `oynatilabilir` SUNUCUDAN gelir (turden turer): hls/mp4 -> true,
/// rtsp -> false. Istemci RTSP'yi natively oynatamaz; kart rozet gosterir ve
/// dokunma oynatici yerine bilgi kartini acar.
library;

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
  List<String> get semalar =>
      this == CameraTur.rtsp ? const ['rtsp://'] : const ['http://', 'https://'];

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
    bool? oynatilabilir,
  }) : _oynatilabilir = oynatilabilir; // ignore: prefer_initializing_formals


  final String id;
  final String ad;

  /// Serbest konum metni (orn. "Ana Kapı - Giriş"); yoksa null.
  final String? konum;

  final String streamUrl;
  final CameraTur tur;

  /// Pasif kamera yonetimde gorunur, sakine HIC gonderilmez (sunucu suzer).
  final bool aktif;

  /// KVKK anahtari — sakin/tesis gorevlisi gorunurlugu (yonetim acar).
  final bool sakinGorebilir;

  final bool? _oynatilabilir;

  /// Sunucunun `oynatilabilir` alani; yoksa turden turetilir.
  bool get oynatilabilir => _oynatilabilir ?? tur.oynatilabilir;

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        konum: json['konum'] as String?,
        streamUrl: json['stream_url'] as String? ?? '',
        tur: CameraTur.fromWire(json['tur'] as String?),
        aktif: json['aktif'] as bool? ?? true,
        sakinGorebilir: json['sakin_gorebilir'] as bool? ?? false,
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
  });

  final String ad;

  /// Bos ise PATCH'te ACIK null gonderilir (konum kaldirilir).
  final String? konum;

  final String streamUrl;
  final CameraTur tur;
  final bool aktif;
  final bool sakinGorebilir;

  /// Olusturma govdesi — bos konum HIC yazilmaz (sunucu minLength 1).
  Map<String, dynamic> toCreateJson() => {
        'ad': ad,
        if (konum != null && konum!.isNotEmpty) 'konum': konum,
        'stream_url': streamUrl,
        'tur': tur.wire,
        'aktif': aktif,
        'sakin_gorebilir': sakinGorebilir,
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
      };

  /// Istemci tarafi URL/tur tutarlilik kontrolu — sunucudaki 422 kuralinin
  /// AYNISI (hls/mp4 -> http(s), rtsp -> rtsp://). Gecerliyse null, degilse
  /// kullaniciya gosterilecek TR mesaj.
  static String? urlHatasi(String url, CameraTur tur) {
    final u = url.trim();
    if (u.isEmpty) return 'Yayın adresi zorunludur';
    if (tur.semalar.any(u.startsWith)) return null;
    return switch (tur) {
      CameraTur.rtsp => 'RTSP yayın adresi rtsp:// ile başlamalı',
      _ => '${tur.label} yayın adresi http:// veya https:// ile başlamalı',
    };
  }
}
