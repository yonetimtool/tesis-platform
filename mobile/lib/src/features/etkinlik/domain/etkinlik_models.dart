/// Etkinlik modulunun domain modelleri — `contracts/openapi.yaml`
/// Etkinlik / EtkinlikCreate / EtkinlikUpdate / EtkinlikRsvp semalarina uyar.
///
/// Akis (urun sahibi sabit): yonetici etkinlik olusturur (cenaze/mac izleme
/// vb.) -> tum sakinlere push -> sakin katiliyorum/katilmiyorum beyan eder
/// (kullanici basina TEK kayit, KILITLI — ilk beyandan sonra degistirilemez;
/// backend tekrar PUT'a 409 doner). SAYILAR SEFFAF: katilim
/// sayisini herkes gorur; kim-katiliyor listesi URUN GEREGI YOK — yalniz
/// sayi + kullanicinin KENDI beyani (benimDurumum).
library;

/// `katilim_durum` enum'unun istemci aynasi (RSVP beyani).
///
/// KIMLIK / METIN AYRIMI (README §15): enum GORUNEN METIN TASIMAZ — etiket
/// cizim aninda `katilimDurumAdi` ile cozulur.
enum KatilimDurum {
  katiliyorum('katiliyorum'),
  katilmiyorum('katilmiyorum');

  const KatilimDurum(this.wire);

  /// Backend enum degeri.
  final String wire;

  /// null/bilinmeyen deger → null (beyan verilmemis sayilir; cokme yok).
  static KatilimDurum? fromWire(String? value) {
    for (final d in KatilimDurum.values) {
      if (d.wire == value) return d;
    }
    return null;
  }
}

class Etkinlik {
  const Etkinlik({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.tarih,
    required this.olusturanUserId,
    required this.katiliyorumSayisi,
    required this.katilmiyorumSayisi,
    required this.createdAt,
    this.bitisZamani,
    this.konum,
    this.fotoKey,
    this.fotoUrl,
    this.olusturanAd,
    this.benimDurumum,
  });

  final String id;
  final String baslik;
  final String aciklama;

  /// Etkinlik BASLANGICI (UTC gelir; gosterimde yerellestirilir).
  final DateTime tarih;

  /// Opsiyonel BITIS; null → anlik etkinlik (bitis = baslangic). Sunucunun
  /// `?aktif=true` suzgeci COALESCE(bitis_zamani, tarih) kullanir.
  final DateTime? bitisZamani;

  final String? konum;

  /// Opsiyonel gorsel — MinIO obje anahtari (varligi "foto var" demektir).
  final String? fotoKey;

  /// Goruntuleme icin kisa omurlu presigned GET URL (sunucu okumada uretir).
  final String? fotoUrl;
  final String olusturanUserId;
  final String? olusturanAd;

  /// SEFFAF sayilar — herkes gorur (kimlik listesi yok).
  final int katiliyorumSayisi;
  final int katilmiyorumSayisi;

  /// Kullanicinin KENDI beyani (beyan yoksa null) — secim gosterimi.
  final KatilimDurum? benimDurumum;

  final DateTime createdAt;

  /// Etkinligin BITTIGI an — bitis verilmemisse baslangic (sunucudaki
  /// COALESCE(bitis_zamani, tarih) ile ayni kural).
  DateTime get bitis => bitisZamani ?? tarih;

  /// Bitisi gecmis mi (liste basliklari icin; suzgec SUNUCUDA yapilir).
  bool get gecmis => bitis.isBefore(DateTime.now());

  /// Baslangici gecti ama bitisi gelmedi → su an SURUYOR.
  bool get suruyor =>
      tarih.isBefore(DateTime.now()) && bitis.isAfter(DateTime.now());

  factory Etkinlik.fromJson(Map<String, dynamic> json) => Etkinlik(
        id: json['id'] as String? ?? '',
        baslik: json['baslik'] as String? ?? '',
        aciklama: json['aciklama'] as String? ?? '',
        tarih: DateTime.tryParse(json['tarih'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        bitisZamani: DateTime.tryParse(json['bitis_zamani'] as String? ?? ''),
        konum: json['konum'] as String?,
        fotoKey: json['foto_key'] as String?,
        fotoUrl: json['foto_url'] as String?,
        olusturanUserId: json['olusturan_user_id'] as String? ?? '',
        olusturanAd: json['olusturan_ad'] as String?,
        katiliyorumSayisi: (json['katiliyorum_sayisi'] as num?)?.toInt() ?? 0,
        katilmiyorumSayisi: (json['katilmiyorum_sayisi'] as num?)?.toInt() ?? 0,
        benimDurumum: KatilimDurum.fromWire(json['benim_durumum'] as String?),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /events` / `PATCH /events/{id}` govdesi (yonetim).
class EtkinlikDraft {
  const EtkinlikDraft({
    required this.baslik,
    required this.aciklama,
    required this.tarih,
    this.bitisZamani,
    this.konum,
    this.fotoKey,
    this.fotoKeyKaldir = false,
  });

  final String baslik;
  final String aciklama;

  /// ISO8601 UTC gonderilir (baslangic).
  final DateTime tarih;

  /// Opsiyonel bitis — sunucu baslangictan SONRA olmasini zorlar (422).
  final DateTime? bitisZamani;

  /// Opsiyonel yer; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? konum;

  /// Yeni gorsel anahtari (presign akisindan); null → alan yazilmaz.
  final String? fotoKey;

  /// PATCH'te gorseli KALDIRMAK icin acik null gonderimi (site kurali/duyuru
  /// ile ayni sozlesme: alan yoksa dokunulmaz, acik null kaldirir).
  final bool fotoKeyKaldir;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'aciklama': aciklama,
        'tarih': tarih.toUtc().toIso8601String(),
        if (bitisZamani != null)
          'bitis_zamani': bitisZamani!.toUtc().toIso8601String(),
        if (konum != null && konum!.isNotEmpty) 'konum': konum,
        if (fotoKey != null)
          'foto_key': fotoKey
        else if (fotoKeyKaldir)
          'foto_key': null,
      };
}
