/// Rezervasyon modulunun domain modelleri — `contracts/openapi.yaml`
/// OrtakAlan / Rezervasyon / *Create / *Update semalarina uyar.
///
/// Akis (urun sahibi sabit): yonetici ortak alan tanimlar -> sakin BOS slotu
/// ANINDA rezerve eder (ONAY YOK; durum=onaylandi). Zamanlama: slota <24s kala
/// acilir, sakin gunde 1 aktif rezervasyon tutar, <10 dk kala bos slot kotayi
/// baypas eder. Sakin/yonetim iptal edebilir (durum=iptal; slot bosalir).
/// CAKISMA ENGELI DB'de: ayni alanin ONAYLI iki rezervasyonu kesisemez —
/// cakisan ikinci talep 409. RBAC (auth.md §4): alan yonetimi admin+yonetici;
/// rezerve etme yalniz resident; iptal rezerve eden sakin + yonetim; okuma
/// yonetim tumu / sakin kendi dairesi; saha rolleri erisemez.
library;

/// `rezervasyon_durum` enum'unun istemci aynasi (onay akisi YOK).
enum RezervasyonDurum {
  onaylandi('onaylandi', 'Onaylı'),
  iptal('iptal', 'İptal'),
  unknown('unknown', 'Bilinmeyen');

  const RezervasyonDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  static RezervasyonDurum fromWire(String? value) =>
      RezervasyonDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => RezervasyonDurum.unknown,
      );
}

/// Rezerve edilebilir ortak alan (havuz/teras/toplanti odasi).
class OrtakAlan {
  const OrtakAlan({
    required this.id,
    required this.ad,
    required this.aktif,
    required this.createdAt,
    this.acilis = '00:00',
    this.kapanis = '23:59',
    this.slotDakika = 60,
    this.aciklama,
  });

  final String id;
  final String ad;
  final String? aciklama;

  /// false = kaldirilmis (soft-delete; rezerve edilemez — yalniz yonetim gorur).
  final bool aktif;

  /// Musaitlik: her gun [acilis, kapanis) araligi, slotDakika slot uzunlugu.
  /// "HH:MM".
  final String acilis;
  final String kapanis;
  final int slotDakika;

  final DateTime createdAt;

  /// "HH:MM · HH:MM (N dk)" — alan kartinda musaitlik ozeti.
  String get musaitlikOzeti => '$acilis–$kapanis · $slotDakika dk slot';

  factory OrtakAlan.fromJson(Map<String, dynamic> json) => OrtakAlan(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        aciklama: json['aciklama'] as String?,
        aktif: json['aktif'] as bool? ?? true,
        acilis: json['acilis'] as String? ?? '00:00',
        kapanis: json['kapanis'] as String? ?? '23:59',
        slotDakika: (json['slot_dakika'] as num?)?.toInt() ?? 60,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// Bir gunun tek slotu (`GET /common-areas/{id}/slots`). GIZLILIK: kim rezerve
/// etmis alani YOK — yalniz saat + dolu/bos + rezerve edilebilirlik.
class Slot {
  const Slot({
    required this.baslangic,
    required this.bitis,
    required this.dolu,
    this.rezerveEdilebilir = false,
    this.sebep,
    this.unitNo,
    this.kisiSayisi,
    this.benim = false,
  });

  /// "HH:MM".
  final String baslangic;
  final String bitis;

  /// true = bu slotla kesisen ONAYLI rezervasyon var (secilemez).
  final bool dolu;

  /// Sakin bu slotu SIMDI rezerve edebilir mi (24s penceresi + gunluk kota +
  /// son-dakika istisnasi; sunucu hesaplar). Yonetimde daima false.
  final bool rezerveEdilebilir;

  /// Rezerve edilemme sebebi: 'dolu' | 'gecti' | 'cok_erken' | 'gunluk' | null.
  final String? sebep;

  /// YALNIZ yonetim (admin/yonetici) + dolu slot: rezerve eden daire no.
  /// resident/saha icin sunucu DAIMA null doner (gizlilik).
  final String? unitNo;

  /// YALNIZ yonetim + dolu slot: rezerve edilen kisi sayisi (resident: null).
  final int? kisiSayisi;

  /// YALNIZ resident: bu dolu slot KENDI rezervasyonu mu (yesil/kirmizi rengi
  /// icin). Baskasinin dolu slotu benim=false + kimlik/kisi null (gizlilik).
  final bool benim;

  /// Sakine gosterilecek kisa sebep etiketi (sebep koduna gore).
  String? get sebepEtiketi => switch (sebep) {
        'dolu' => 'dolu',
        'gecti' => 'geçti',
        'cok_erken' => '24s içinde açılır',
        'gunluk' => 'günlük hakkınız dolu',
        _ => null,
      };

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        baslangic: json['baslangic'] as String? ?? '',
        bitis: json['bitis'] as String? ?? '',
        dolu: json['dolu'] as bool? ?? false,
        rezerveEdilebilir: json['rezerve_edilebilir'] as bool? ?? false,
        sebep: json['sebep'] as String?,
        unitNo: json['unit_no'] as String?,
        kisiSayisi: (json['kisi_sayisi'] as num?)?.toInt(),
        benim: json['benim'] as bool? ?? false,
      );
}

class Rezervasyon {
  const Rezervasyon({
    required this.id,
    required this.alanId,
    required this.unitId,
    required this.tarih,
    required this.baslangic,
    required this.bitis,
    required this.kisiSayisi,
    required this.durum,
    required this.talepEdenUserId,
    required this.createdAt,
    this.alanAd,
    this.unitNo,
    this.notlar,
    this.talepEdenAd,
    this.iptalEdenUserId,
    this.iptalEdenAd,
    this.iptalZamani,
  });

  final String id;
  final String alanId;

  /// Alan adi (sunucu join ile doldurur).
  final String? alanAd;

  final String unitId;
  final String? unitNo;

  /// "YYYY-MM-DD".
  final String tarih;

  /// "HH:MM".
  final String baslangic;

  /// "HH:MM" — baslangictan sonra.
  final String bitis;

  final int kisiSayisi;
  final String? notlar;
  final RezervasyonDurum durum;

  final String talepEdenUserId;
  final String? talepEdenAd;

  /// Iptal eden (sakin/yonetim) + zamani — yalniz durum=iptal'de dolu.
  final String? iptalEdenUserId;
  final String? iptalEdenAd;
  final DateTime? iptalZamani;

  final DateTime createdAt;

  bool get onayli => durum == RezervasyonDurum.onaylandi;
  bool get iptalEdildi => durum == RezervasyonDurum.iptal;

  factory Rezervasyon.fromJson(Map<String, dynamic> json) => Rezervasyon(
        id: json['id'] as String? ?? '',
        alanId: json['alan_id'] as String? ?? '',
        alanAd: json['alan_ad'] as String?,
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        tarih: json['tarih'] as String? ?? '',
        baslangic: json['baslangic'] as String? ?? '',
        bitis: json['bitis'] as String? ?? '',
        kisiSayisi: (json['kisi_sayisi'] as num?)?.toInt() ?? 0,
        notlar: json['notlar'] as String?,
        durum: RezervasyonDurum.fromWire(json['durum'] as String?),
        talepEdenUserId: json['talep_eden_user_id'] as String? ?? '',
        talepEdenAd: json['talep_eden_ad'] as String?,
        iptalEdenUserId: json['iptal_eden_user_id'] as String?,
        iptalEdenAd: json['iptal_eden_ad'] as String?,
        iptalZamani: json['iptal_zamani'] == null
            ? null
            : DateTime.tryParse(json['iptal_zamani'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /reservations` govdesi (yalniz sakin). Daire sunucuda kimlikten
/// turetilir (coklu dairede unitId ile secim yapilabilir).
class RezervasyonDraft {
  const RezervasyonDraft({
    required this.alanId,
    required this.tarih,
    required this.baslangic,
    required this.bitis,
    required this.kisiSayisi,
    this.notlar,
  });

  final String alanId;

  /// "YYYY-MM-DD".
  final String tarih;

  /// "HH:MM".
  final String baslangic;
  final String bitis;
  final int kisiSayisi;

  /// Opsiyonel not; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'alan_id': alanId,
        'tarih': tarih,
        'baslangic': baslangic,
        'bitis': bitis,
        'kisi_sayisi': kisiSayisi,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}

/// `POST /common-areas` / `PATCH /common-areas/{id}` govdesi (yonetim).
class OrtakAlanDraft {
  const OrtakAlanDraft({
    required this.ad,
    this.aciklama,
    this.aktif,
    this.acilis,
    this.kapanis,
    this.slotDakika,
  });

  final String ad;
  final String? aciklama;

  /// Yalniz PATCH'te anlamli (soft-delete/aktive); null ise gonderilmez.
  final bool? aktif;

  /// Musaitlik ("HH:MM"). null ise gonderilmez (sunucu varsayilani/mevcut).
  final String? acilis;
  final String? kapanis;
  final int? slotDakika;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        if (aciklama != null && aciklama!.isNotEmpty) 'aciklama': aciklama,
        if (aktif != null) 'aktif': aktif,
        if (acilis != null) 'acilis': acilis,
        if (kapanis != null) 'kapanis': kapanis,
        if (slotDakika != null) 'slot_dakika': slotDakika,
      };
}
