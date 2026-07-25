/// BIRLESIK AKTIVITE AKISI (`GET /activity`) domain modelleri — G5.
///
/// Akis artik ISTEMCIDE BIRLESTIRILMEZ: sunucu 13 kaynagi birlestirir,
/// siralar ve rol/KVKK'ya gore suzer (bkz. `contracts/openapi.yaml` →
/// `/activity`). Bu yuzden burada "hangi rol hangi ucu cagirabilir" bilgisi
/// YOKTUR — ekran ne gelirse cizer, sunucu ne gonderirse dogrudur.
///
/// KVKK notu: admin/yonetici bu akista ziyaretci/kargo olaylarini GORMEZ
/// (o uclar yonetime varsayilan kapali, tek-seferlik izinle acilir). Istemci
/// bu olaylari yerel olarak GERI EKLEMEZ — akis o kapiyi bypass eden bir yan
/// kanal olmamalidir.
library;

/// Akis olayinin turu (`ActivityItem.tur`). Sunucu ileride yeni tur
/// ekleyebilir → taninmayan deger [ActivityTur.bilinmeyen] olur ve satir
/// AKISTA KALIR (nötr ikonla): olay dusurmek "bir sey olmadi" yalanidir.
enum ActivityTur {
  devriyeOkutma,
  gorevTamamlama,
  aidatOdeme,
  talep,
  daireSikayeti,
  alarm,
  ziyaretciGiris,
  ziyaretciCikis,
  kargo,
  kargoTeslim,
  aracGiris,
  aracCikis,
  ihlal,
  bilinmeyen;

  static ActivityTur fromWire(String? wire) => switch (wire) {
        'devriye_okutma' => devriyeOkutma,
        'gorev_tamamlama' => gorevTamamlama,
        'aidat_odeme' => aidatOdeme,
        'talep' => talep,
        'daire_sikayeti' => daireSikayeti,
        'alarm' => alarm,
        'ziyaretci_giris' => ziyaretciGiris,
        'ziyaretci_cikis' => ziyaretciCikis,
        'kargo' => kargo,
        'kargo_teslim' => kargoTeslim,
        'arac_giris' => aracGiris,
        'arac_cikis' => aracCikis,
        'ihlal' => ihlal,
        _ => bilinmeyen,
      };
}

/// Sunucunun UI nokta/rozet rengi ipucu (`renk_ipucu`). Yoksa [notr].
enum ActivityRenk {
  olumlu,
  uyari,
  alarm,
  notr;

  static ActivityRenk fromWire(String? wire) => switch (wire) {
        'olumlu' => olumlu,
        'uyari' => uyari,
        'alarm' => alarm,
        _ => notr,
      };
}

/// Akisin tek satiri (`ActivityItem`). Basliklar/alt metinler SUNUCUDAN
/// gelir — istemci metin uretmez, yalniz ikon/renk/zaman etiketi ekler.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.tur,
    required this.baslik,
    required this.zaman,
    required this.kaynakId,
    this.altMetin,
    this.renk = ActivityRenk.notr,
  });

  /// Kaynaklar arasi benzersiz olay kimligi (`"<tur>:<kaynak_id>"`).
  final String id;

  final ActivityTur tur;
  final String baslik;
  final String? altMetin;

  /// Olayin GERCEKLESME zamani — YEREL saate cevrilmis (sunucu UTC gonderir;
  /// "09:47" etiketi cihaz saatiyle tutarli olsun diye).
  final DateTime zaman;

  final ActivityRenk renk;

  /// Kaynak kaydin kendi id'si (derin baglanti icin).
  final String kaynakId;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'] as String? ?? '',
        tur: ActivityTur.fromWire(json['tur'] as String?),
        baslik: json['baslik'] as String? ?? '',
        altMetin: json['alt_metin'] as String?,
        zaman: (DateTime.tryParse(json['zaman'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
            .toLocal(),
        renk: ActivityRenk.fromWire(json['renk_ipucu'] as String?),
        kaynakId: json['kaynak_id'] as String? ?? '',
      );
}

/// `GET /activity` sayfasi. `offset` ve `meta.total` YOKTUR (bilincli):
/// imlec araya giren kayitta sayfayi kaydirmaz, 13 kaynagin birlesik
/// toplamı ise her istekte tam tarama demektir.
class ActivityPage {
  const ActivityPage({required this.items, this.nextCursor});

  final List<ActivityItem> items;

  /// Bir sonraki sayfanin OPAK imleci; **null ise akisin sonu**.
  /// Istemci icerigini ayristirmaz.
  final String? nextCursor;

  factory ActivityPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final meta = json['meta'];
    return ActivityPage(
      items: [
        for (final item in items is List ? items : const [])
          if (item is Map)
            ActivityItem.fromJson(Map<String, dynamic>.from(item)),
      ],
      nextCursor: meta is Map ? meta['next_cursor'] as String? : null,
    );
  }
}
