/// Ihlal kaydi modelleri — `contracts/openapi.yaml` Violation /
/// ViolationCreate / ViolationUpdate semalarina uyar.
///
/// `site_kurali` YALNIZ kural METNINI tutar; somut ihlal olayi (kim/nerede/
/// nasil tespit etti + is akisi) burada izlenir.
///
/// RBAC (sozlesme): OKUMA admin + yonetici + security; ACMA admin + security
/// (yonetici okur, acmaz); DURUM DEGISTIRME admin + security; **KAPATMA
/// YALNIZ admin** (dort-goz kurali — inceleyen personel kendi kaydini
/// kapatamaz). `kapatildi` TERMINAL: yeniden acilmaz (409).
library;

/// KIMLIK / METIN AYRIMI (README §15): enum'lar GORUNEN METIN TASIMAZ.
enum IhlalDurum {
  yeni('yeni'),
  inceleniyor('inceleniyor'),
  kapatildi('kapatildi');

  const IhlalDurum(this.wire);
  final String wire;

  static IhlalDurum fromWire(String? w) => switch (w) {
    'inceleniyor' => IhlalDurum.inceleniyor,
    'kapatildi' => IhlalDurum.kapatildi,
    _ => IhlalDurum.yeni,
  };

  /// Terminal durum — buradan cikis YOK.
  bool get terminal => this == IhlalDurum.kapatildi;
}

enum IhlalKaynak {
  kamera('kamera'),
  manuel('manuel'),
  devriye('devriye');

  const IhlalKaynak(this.wire);
  final String wire;

  static IhlalKaynak fromWire(String? w) => switch (w) {
    'kamera' => IhlalKaynak.kamera,
    'devriye' => IhlalKaynak.devriye,
    _ => IhlalKaynak.manuel,
  };
}

class Ihlal {
  const Ihlal({
    required this.id,
    required this.baslik,
    required this.kaynak,
    required this.durum,
    required this.olusturanUserId,
    required this.createdAt,
    required this.updatedAt,
    this.aciklama,
    this.konum,
    this.olusturanAd,
  });

  final String id;
  final String baslik;
  final String? aciklama;
  final IhlalKaynak kaynak;

  /// Serbest konum METNI — checkpoint FK DEGIL (ihlal cogu zaman checkpoint
  /// disinda tespit edilir).
  final String? konum;

  final IhlalDurum durum;
  final String olusturanUserId;
  final String? olusturanAd;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Ihlal.fromJson(Map<String, dynamic> json) => Ihlal(
    id: json['id'] as String? ?? '',
    baslik: json['baslik'] as String? ?? '',
    aciklama: json['aciklama'] as String?,
    kaynak: IhlalKaynak.fromWire(json['kaynak'] as String?),
    konum: json['konum'] as String?,
    durum: IhlalDurum.fromWire(json['durum'] as String?),
    olusturanUserId: json['olusturan_user_id'] as String? ?? '',
    olusturanAd: json['olusturan_ad'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

/// `POST /violations` govdesi.
class IhlalDraft {
  const IhlalDraft({
    required this.baslik,
    this.aciklama,
    this.kaynak = IhlalKaynak.manuel,
    this.konum,
  });

  final String baslik;
  final String? aciklama;
  final IhlalKaynak kaynak;
  final String? konum;

  Map<String, dynamic> toJson() => {
    'baslik': baslik,
    if (aciklama != null && aciklama!.isNotEmpty) 'aciklama': aciklama,
    'kaynak': kaynak.wire,
    if (konum != null && konum!.isNotEmpty) 'konum': konum,
  };
}

/// Bir durumdan gidilebilecek SONRAKI durumlar (akis: yeni → inceleniyor →
/// kapatildi). Sunucu kurali istemcide de uygulanir ki kullaniciya
/// gerceklestirilemeyecek dugme gosterilmesin — gercek yetki backend'de.
///
/// [adminMi]: kapatma YALNIZ admin'e aciktir.
List<IhlalDurum> ihlalSonrakiDurumlar(
  IhlalDurum mevcut, {
  required bool adminMi,
}) {
  if (mevcut.terminal) return const [];
  return [
    if (mevcut == IhlalDurum.yeni) IhlalDurum.inceleniyor,
    if (adminMi) IhlalDurum.kapatildi,
  ];
}
