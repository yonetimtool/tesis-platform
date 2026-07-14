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
enum KatilimDurum {
  katiliyorum('katiliyorum', 'Katılıyorum'),
  katilmiyorum('katilmiyorum', 'Katılmıyorum');

  const KatilimDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

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
    this.konum,
    this.olusturanAd,
    this.benimDurumum,
  });

  final String id;
  final String baslik;
  final String aciklama;

  /// Etkinlik zamani (UTC gelir; gosterimde yerellestirilir).
  final DateTime tarih;

  final String? konum;
  final String olusturanUserId;
  final String? olusturanAd;

  /// SEFFAF sayilar — herkes gorur (kimlik listesi yok).
  final int katiliyorumSayisi;
  final int katilmiyorumSayisi;

  /// Kullanicinin KENDI beyani (beyan yoksa null) — secim gosterimi.
  final KatilimDurum? benimDurumum;

  final DateTime createdAt;

  bool get gecmis => tarih.isBefore(DateTime.now());

  factory Etkinlik.fromJson(Map<String, dynamic> json) => Etkinlik(
        id: json['id'] as String? ?? '',
        baslik: json['baslik'] as String? ?? '',
        aciklama: json['aciklama'] as String? ?? '',
        tarih: DateTime.tryParse(json['tarih'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        konum: json['konum'] as String?,
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
    this.konum,
  });

  final String baslik;
  final String aciklama;

  /// ISO8601 UTC gonderilir.
  final DateTime tarih;

  /// Opsiyonel yer; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? konum;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'aciklama': aciklama,
        'tarih': tarih.toUtc().toIso8601String(),
        if (konum != null && konum!.isNotEmpty) 'konum': konum,
      };
}
