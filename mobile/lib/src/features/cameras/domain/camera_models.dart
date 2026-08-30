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

  /// (P121) Adres bir WEB SAYFASI — YouTube/Vimeo baglantisi, belediye
  /// izleyici sayfasi, DVR'in web arayuzu...
  ///
  /// SUNUCU BUNU REDDETMEZ ve REDDEDEMEZ: sema kontrolu `https://` gorur ve
  /// gecerli sayar. Oysa oynatici `video_player`dir; DOGRUDAN medya akisi
  /// bekler (HLS `.m3u8` ya da MP4) ve bir HTML sayfasini oynatamaz.
  /// Kullanici acisindan belirti "kaydettim ama acilmiyor"dur ve teshis
  /// kamerada aranir — oysa hata KAYITTADIR. Bu yuzden istemci ACIKCA
  /// reddeder, sessizce kabul edip sonra bos ekran gostermez.
  webSayfasi,
}

/// Bilinen web sayfasi barindiricilari — bunlar bir MEDYA AKISI degil,
/// icinde oynatici BULUNAN bir sayfa dondurur.
///
/// Liste TAM DEGIL ve olamaz; amaci sahada gercekten yapistirilan uc-bes
/// adresi yakalamaktir. Genel kural [_medyaUzantisi] ile ayrica olculur:
/// bir HTTP adresi ne `.m3u8` ne `.mp4` ile bitiyorsa ve bilinen bir
/// barindiriciysa, oynatilamayacagi KESINDIR.
const _webBarindiricilari = {
  'youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be',
  'vimeo.com', 'www.vimeo.com', 'player.vimeo.com',
  'dailymotion.com', 'www.dailymotion.com',
  'twitch.tv', 'www.twitch.tv',
  'facebook.com', 'www.facebook.com', 'fb.watch',
  'instagram.com', 'www.instagram.com',
};

/// Adres dogrudan bir medya dosyasina mi isaret ediyor?
///
/// Sorgu dizesi ATILIR: `.../stream.m3u8?token=abc` gecerli bir HLS
/// adresidir ve sorguyu saymak onu reddederdi.
bool _medyaUzantisi(Uri uri) {
  final yol = uri.path.toLowerCase();
  return yol.endsWith('.m3u8') || yol.endsWith('.mp4') || yol.endsWith('.m3u');
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
    this.snapshotUrl,
    this.canliYol,
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

  /// (P121) TEK KARE dondüren adres (image/jpeg); yoksa null.
  ///
  /// Izgara karosu OYNATICI ACMADAN bunu periyodik ceker. Video DEGILDIR:
  /// dolu olmasi kamerayi oynatilabilir YAPMAZ — kullanici karoda goruntu
  /// gorup dokundugunda oynaticinin acilmamasi kabul edilebilir bir
  /// tutarsizlik olurdu, bu yuzden iki kavram ayri tutulur.
  final String? snapshotUrl;

  /// (P190 §6) RTSP→HLS gecidinin GORELI API yolu
  /// (`/cameras/{id}/canli/index.m3u8`); gecit yapilandirilmamissa null.
  ///
  /// Adres API'ye GORELIDIR ve oynatilirken `Authorization: Bearer` baslik
  /// GEREKTIRIR (parca istekleri listeye goreli, ayni yetki). `restreamUrl`
  /// gibi kamera-basina elle girilen bir gecit DEGIL, sunucunun kendi
  /// yayin ucudur.
  final String? canliYol;

  /// Karo periyodik kare cekebilir mi?
  ///
  /// (P190 §6) `snapshot_url` yoksa RTSP kameralar da cekebilir: sunucu
  /// `GET /cameras/{id}/kare` ile kareyi KENDI yakalar (RTSP kimlik
  /// bilgileri istemciye HIC inmez).
  bool get kareCekilebilir =>
      (snapshotUrl != null && snapshotUrl!.isNotEmpty) ||
      tur == CameraTur.rtsp;

  final CameraTur tur;

  /// Pasif kamera yonetimde gorunur, sakine HIC gonderilmez (sunucu suzer).
  final bool aktif;

  /// KVKK anahtari — sakin/tesis gorevlisi gorunurlugu (yonetim acar).
  final bool sakinGorebilir;

  final bool? _oynatilabilir;

  /// Sunucunun `oynatilabilir` alani; yoksa YERELDE ayni kural uygulanir
  /// (canli yol/restream varsa true, yoksa ture bak) — eski sunucuya karsi
  /// geri dusus. (P190 §6) Sunucu `canli_yol` doluyken zaten true gonderir.
  bool get oynatilabilir =>
      _oynatilabilir ??
      ((canliYol != null || restreamUrl != null) ? true : tur.oynatilabilir);

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
    snapshotUrl: json['snapshot_url'] as String?,
    canliYol: json['canli_yol'] as String?,
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
    this.snapshotUrl,
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

  /// Opsiyonel anlik kare adresi (P121). Bos ise gonderilmez/temizlenir.
  final String? snapshotUrl;

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
    if (snapshotUrl != null && snapshotUrl!.isNotEmpty)
      'snapshot_url': snapshotUrl,
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
    // ACIK null: bos birakilirsa kare adresi KALDIRILIR (karo yer tutucuya
    // doner) — `restream_url` ile ayni sozlesme.
    'snapshot_url': (snapshotUrl == null || snapshotUrl!.isEmpty)
        ? null
        : snapshotUrl,
  };

  /// Istemci tarafi URL/tur tutarlilik kontrolu — sunucudaki 422 kuralinin
  /// AYNISI (hls/mp4 -> http(s), rtsp -> rtsp://).
  ///
  /// METIN DONDURMEZ: domain katmani dil bilmez (i18n). Hata TURU doner;
  /// kullaniciya gosterilecek metni form katmani aktif dilden secer
  /// (bkz. kamera_form_sheet.dart).
  /// Restream adresi dogrulamasi — YALNIZ http(s) (sunucudaki kuralin
  /// aynisi). Bos/null gecerlidir (gecit yok demektir).
  /// (P121) Anlik kare adresi dogrulamasi — YALNIZ http(s), web sayfasi
  /// DEGIL. Sunucudaki `dogrula_snapshot` kuralinin istemci aynasi.
  static CameraUrlHatasi? snapshotHatasi(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    if (u.length > kCameraUrlUstSinir) return CameraUrlHatasi.cokUzun;
    if (webSayfasiMi(u)) return CameraUrlHatasi.webSayfasi;
    if (u.startsWith('http://') || u.startsWith('https://')) return null;
    return CameraUrlHatasi.httpSemasiGerekli;
  }

  static CameraUrlHatasi? restreamHatasi(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    if (u.length > kCameraUrlUstSinir) return CameraUrlHatasi.cokUzun;
    if (u.startsWith('http://') || u.startsWith('https://')) return null;
    return CameraUrlHatasi.httpSemasiGerekli;
  }

  /// (P121) Adres bir web SAYFASI mi (oynatilamaz)?
  ///
  /// YALNIZ http(s) icin anlamlidir; `rtsp://` zaten ayri bir yoldan
  /// degerlendirilir.
  static bool webSayfasiMi(String url) {
    final u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) return false;
    if (_medyaUzantisi(uri)) return false;
    return _webBarindiricilari.contains(uri.host.toLowerCase());
  }

  static CameraUrlHatasi? urlHatasi(String url, CameraTur tur) {
    final u = url.trim();
    if (u.isEmpty) return CameraUrlHatasi.bos;
    // UZUNLUK SEMADAN ONCE: 3 KB'lik bir yapistirmada "https ile baslamali"
    // demek yaniltici olurdu — adres zaten https ile BASLIYOR olabilir.
    if (u.length > kCameraUrlUstSinir) return CameraUrlHatasi.cokUzun;
    // (P121) WEB SAYFASI KONTROLU SEMA KONTROLUNDEN ONCE.
    // `https://youtube.com/watch?v=…` sema kontrolunu GECER; once o
    // calisirsa kullanici hicbir uyari almadan OYNAMAYAN bir kamera
    // kaydeder ve hatayi kamerada arar — oysa hata kayittadir.
    if (webSayfasiMi(u)) return CameraUrlHatasi.webSayfasi;
    if (tur.semalar.any(u.startsWith)) return null;
    return tur == CameraTur.rtsp
        ? CameraUrlHatasi.rtspSemasiGerekli
        : CameraUrlHatasi.httpSemasiGerekli;
  }
}
