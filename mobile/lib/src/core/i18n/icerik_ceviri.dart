/// ICERIK CEVIRISI USTVERISI — `contracts/openapi.yaml` `CeviriAlanlari`.
///
/// Yayin icerigi (duyuru / site kurali / etkinlik) yonetimin YAZDIGI dilde
/// saklanir, yazma aninda 6 hedef dile cevrilir ve okuma `Accept-Language`
/// ile servis edilir. Govdedeki metin alanlari ZATEN secilen dildedir; bu
/// sinif o metnin NE OLDUGUNU soyler:
///
///   * `ceviriDurumu` = `bekliyor`/`hata` → govdedeki metin ORIJINALDIR
///     (sunucu yarim ceviri servis etmez), kullaniciya "çeviri hazırlanıyor"
///     denir;
///   * `cevirildiMi` = true → metin MAKINE cevirisidir, kullaniciya
///     "otomatik çevrilmiştir" denir ve orijinaline donme yolu acilir;
///   * `orijinal` HER ZAMAN gelir — orijinali gormek icin ikinci istek ya da
///     `?dil=orijinal` GEREKMEZ.
///
/// Yonetici bir dildeki makine cevirisini ELLE duzeltmisse `cevirildiMi`
/// false doner: duzeltilmis metin artik makine ciktisi degildir, rozet
/// gosterilmez.
///
/// SUNUCU USTVERI GONDERMEZSE (eski surum / cevrilmeyen tip) alan `null`
/// kalir ve ekranlar hicbir not gostermez — davranis eski haliyle aynidir.
library;

/// `ceviri_durumu` enum'unun istemci aynasi.
///
/// KIMLIK / METIN AYRIMI (README §15): enum GORUNEN METIN TASIMAZ.
enum CeviriDurumu {
  hazir('hazir'),
  bekliyor('bekliyor'),
  hata('hata');

  const CeviriDurumu(this.wire);
  final String wire;

  /// Bilinmeyen/eksik deger `hazir` sayilir: sunucu yeni bir durum eklerse
  /// kullaniciya YANLIS bir "hazırlanıyor" notu gostermek, metni oldugu gibi
  /// gostermekten kotudur.
  static CeviriDurumu fromWire(String? w) => switch (w) {
    'bekliyor' => CeviriDurumu.bekliyor,
    'hata' => CeviriDurumu.hata,
    _ => CeviriDurumu.hazir,
  };
}

class IcerikCeviri {
  const IcerikCeviri({
    required this.orijinalDil,
    required this.gosterilenDil,
    required this.durum,
    required this.cevirildiMi,
    required this.orijinal,
  });

  /// Icerigin YAZILDIGI dil (su an her zaman `tr`).
  final String orijinalDil;

  /// Govdedeki metnin GERCEK dili. Ceviri hazir degilse `orijinalDil`e esittir.
  final String gosterilenDil;

  final CeviriDurumu durum;

  /// Govdedeki metin MAKINE cevirisi mi?
  final bool cevirildiMi;

  /// Kaynak dildeki metinler (alan adi -> metin). Her zaman dolu gelir.
  final Map<String, String> orijinal;

  /// Ustveri yoksa `null` doner — cagiran taraf not gostermez.
  static IcerikCeviri? fromJson(Map<String, dynamic> json) {
    // Alanlarin HICBIRI yoksa ustveri gonderilmemistir. `orijinal_dil`
    // tek basina yeter: sema onu zorunlu tutar.
    if (json['orijinal_dil'] == null && json['ceviri_durumu'] == null) {
      return null;
    }
    final ham = json['orijinal'];
    return IcerikCeviri(
      orijinalDil: json['orijinal_dil'] as String? ?? 'tr',
      gosterilenDil: json['gosterilen_dil'] as String? ?? 'tr',
      durum: CeviriDurumu.fromWire(json['ceviri_durumu'] as String?),
      cevirildiMi: json['cevirildi_mi'] as bool? ?? false,
      orijinal: ham is Map
          ? {
              for (final e in ham.entries)
                if (e.value is String) '${e.key}': e.value as String,
            }
          : const {},
    );
  }

  /// Ceviri hazir degil → govdede ORIJINAL metin var, kullaniciya beklemesi
  /// soylenir.
  bool get hazirlaniyor => durum == CeviriDurumu.bekliyor;

  /// Saglayici basarisiz oldu → govdede ORIJINAL metin var.
  bool get hataliCeviri => durum == CeviriDurumu.hata;

  /// Kullaniciya bir not gosterilmeli mi?
  ///
  /// Uc hal: makine cevirisi okunuyor, ceviri hazirlaniyor ya da ceviri
  /// basarisiz. Kaynak dili okuyan kullanici (tr) icin UCU DE false'tur —
  /// gereksiz rozet gostermeyiz.
  bool get notVar => cevirildiMi || hazirlaniyor || hataliCeviri;

  /// Orijinaline DONULEBILIR mi? Yalniz makine cevirisi okunurken anlamli:
  /// hazirlaniyor/hata hallerinde govde zaten orijinaldir.
  bool get orijinaleDonulebilir =>
      cevirildiMi && orijinal.values.any((v) => v.trim().isNotEmpty);

  /// [alan] icin gosterilecek metin.
  ///
  /// [servisEdilen] sunucunun govdede verdigi metindir (cevrilmis olabilir).
  /// [orijinalGoster] true ise kaynak dildeki metin dondurulur; o alan
  /// ustveride yoksa servis edilen metne DUSULUR (bos ekran gostermeyiz).
  String metin(
    String alan,
    String servisEdilen, {
    required bool orijinalGoster,
  }) {
    if (!orijinalGoster) return servisEdilen;
    final o = orijinal[alan];
    return (o == null || o.isEmpty) ? servisEdilen : o;
  }
}

/// `IcerikCeviri?` ustunde null-guvenli metin secimi — ekranlarda her
/// cagriyi `?.` ile sarmaktan kurtarir.
String ceviriMetni(
  IcerikCeviri? ceviri,
  String alan,
  String servisEdilen, {
  required bool orijinalGoster,
}) =>
    ceviri?.metin(alan, servisEdilen, orijinalGoster: orijinalGoster) ??
    servisEdilen;
