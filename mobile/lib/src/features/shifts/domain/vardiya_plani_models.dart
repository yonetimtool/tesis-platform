/// (P203 §4) Vardiya plani modelleri.
library;

class VardiyaKisi {
  const VardiyaKisi({
    required this.planId,
    required this.userId,
    required this.ad,
    required this.rol,
  });

  final String planId;
  final String userId;
  final String ad;
  final String rol;

  factory VardiyaKisi.fromJson(Map<String, dynamic> j) => VardiyaKisi(
        planId: j['plan_id'] as String,
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
      );
}

class VardiyaSlot {
  const VardiyaSlot({
    required this.shiftId,
    required this.shiftAd,
    required this.baslangicSaat,
    required this.bitisSaat,
    this.kisiler = const [],
    this.bos = false,
  });

  final String shiftId;
  final String shiftAd;
  final String baslangicSaat;
  final String bitisSaat;
  final List<VardiyaKisi> kisiler;

  /// Sunucudan gelir; `kisiler`den turetilebilir ama istemcinin her
  /// cizim yerinde "uzunluk 0" kontrolu tekrarlamasi, birinde
  /// unutulmasi demekti — ve bos vardiya BELIRGIN olmazdi.
  final bool bos;

  /// `"08:00:00"` -> `"08:00"`. Saniye vardiya saatinde bilgi tasimaz.
  String get saatAraligi =>
      '${baslangicSaat.substring(0, 5)}–${bitisSaat.substring(0, 5)}';

  factory VardiyaSlot.fromJson(Map<String, dynamic> j) => VardiyaSlot(
        shiftId: j['shift_id'] as String,
        shiftAd: (j['shift_ad'] as String?) ?? '',
        baslangicSaat: (j['baslangic_saat'] as String?) ?? '00:00:00',
        bitisSaat: (j['bitis_saat'] as String?) ?? '00:00:00',
        kisiler: ((j['kisiler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        bos: (j['bos'] as bool?) ?? false,
      );
}

class VardiyaGunu {
  const VardiyaGunu({required this.tarih, this.slotlar = const []});

  final String tarih;
  final List<VardiyaSlot> slotlar;

  factory VardiyaGunu.fromJson(Map<String, dynamic> j) => VardiyaGunu(
        tarih: (j['tarih'] as String?) ?? '',
        slotlar: ((j['slotlar'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaSlot.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class VardiyaHafta {
  const VardiyaHafta({this.gunler = const []});

  final List<VardiyaGunu> gunler;

  factory VardiyaHafta.fromJson(Map<String, dynamic> j) => VardiyaHafta(
        gunler: ((j['gunler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaGunu.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class VardiyaSimdi {
  const VardiyaSimdi({
    this.gorevdekiVardiya,
    this.gorevdekiler = const [],
    this.sonrakiVardiya,
    this.sonrakiler = const [],
  });

  final VardiyaSlot? gorevdekiVardiya;
  final List<VardiyaKisi> gorevdekiler;
  final VardiyaSlot? sonrakiVardiya;
  final List<VardiyaKisi> sonrakiler;

  factory VardiyaSimdi.fromJson(Map<String, dynamic> j) => VardiyaSimdi(
        gorevdekiVardiya: j['gorevdeki_vardiya'] == null
            ? null
            : VardiyaSlot.fromJson(
                Map<String, dynamic>.from(j['gorevdeki_vardiya'] as Map)),
        gorevdekiler: ((j['gorevdekiler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        sonrakiVardiya: j['sonraki_vardiya'] == null
            ? null
            : VardiyaSlot.fromJson(
                Map<String, dynamic>.from(j['sonraki_vardiya'] as Map)),
        sonrakiler: ((j['sonrakiler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

// ==================== (P205 §2) ZAMAN CIZELGESI ============================ #

/// Cizelgedeki TEK bir vardiya blogu.
///
/// SAATLER SUNUCUDA COZULMUS gelir (`baslar`/`biter` tam damga):
/// "sablon mu satirin kendi saati mi" secimini istemciye yaptirmak,
/// ayni kurali web'de ve mobilde IKI KEZ yazmak olurdu.
class VardiyaBlok {
  const VardiyaBlok({
    required this.planId,
    required this.tarih,
    required this.baslar,
    required this.biter,
    this.shiftAd,
    this.notMetni,
    this.geceAsiyor = false,
    this.vardiyaRolu,
    this.blokAd,
    this.alan,
    this.calismaSaat = 0,
    this.molaDakika = 0,
    this.yayinlandiAt,
  });

  final String planId;
  final String tarih;
  final DateTime baslar;
  final DateTime biter;

  /// Sablondan geliyorsa adi; SERBEST vardiyada null.
  final String? shiftAd;
  final String? notMetni;

  /// 22:00-05:00 gibi ERTESI GUNE tasan vardiya.
  final bool geceAsiyor;

  // --------------------- (P241 §2) YENI ALANLAR ------------------------ //
  /// BU VARDIYADAKI rol (`app_user.role` DEGIL).
  final String? vardiyaRolu;
  final String? blokAd;
  final String? alan;

  /// MOLA DUSULMUS calisma suresi — SUNUCUDAN. Istemcide hesaplamak,
  /// kanunun mola kuralini ikinci kez yazmak olurdu.
  final double calismaSaat;
  final int molaDakika;

  /// NULL = TASLAK. Personel taslagi zaten GORMEZ (sunucu suzuyor);
  /// yonetim mobilde de isaretli gorur.
  final String? yayinlandiAt;

  bool get taslak => yayinlandiAt == null;

  String get saatAraligi => '${_ss(baslar)}–${_ss(biter)}';

  /// Hucrede yazan yer bilgisi: blok ya da serbest alan.
  String? get yer => blokAd ?? alan;

  static String _ss(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  factory VardiyaBlok.fromJson(Map<String, dynamic> j) => VardiyaBlok(
        planId: j['plan_id'] as String,
        tarih: (j['tarih'] as String?) ?? '',
        baslar: DateTime.parse(j['baslar'] as String),
        biter: DateTime.parse(j['biter'] as String),
        shiftAd: j['shift_ad'] as String?,
        notMetni: j['not_metni'] as String?,
        geceAsiyor: (j['gece_asiyor'] as bool?) ?? false,
        vardiyaRolu: j['vardiya_rolu'] as String?,
        blokAd: j['blok_ad'] as String?,
        alan: j['alan'] as String?,
        calismaSaat: (j['calisma_saat'] as num?)?.toDouble() ?? 0,
        molaDakika: (j['mola_dakika'] as num?)?.toInt() ?? 0,
        yayinlandiAt: j['yayinlandi_at'] as String?,
      );
}

/// (P241 §2) ONAYLI izin — vardiya blogundan AYRI katman.
class VardiyaIzinBlok {
  const VardiyaIzinBlok({
    required this.izinId,
    required this.tur,
    required this.baslangic,
    required this.bitis,
    this.tumGun = true,
  });

  final String izinId;
  final String tur;
  final String baslangic;
  final String bitis;
  final bool tumGun;

  bool kapsar(String gun) => baslangic.compareTo(gun) <= 0 && bitis.compareTo(gun) >= 0;

  factory VardiyaIzinBlok.fromJson(Map<String, dynamic> j) => VardiyaIzinBlok(
        izinId: j['izin_id'] as String,
        tur: j['tur'] as String? ?? 'yillik',
        baslangic: j['baslangic'] as String? ?? '',
        bitis: j['bitis'] as String? ?? '',
        tumGun: j['tum_gun'] as bool? ?? true,
      );
}


class VardiyaCizelgeKisi {
  const VardiyaCizelgeKisi({
    required this.userId,
    required this.ad,
    required this.rol,
    this.bloklar = const [],
    this.izinler = const [],
    this.toplamSaat = 0,
    this.hedefSaat = 0,
  });

  final String userId;
  final String ad;
  final String rol;
  final List<VardiyaBlok> bloklar;

  /// (P241 §2) Onayli izinler ve donem toplami — SUNUCUDAN.
  final List<VardiyaIzinBlok> izinler;
  final double toplamSaat;
  final double hedefSaat;

  factory VardiyaCizelgeKisi.fromJson(Map<String, dynamic> j) =>
      VardiyaCizelgeKisi(
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
        bloklar: ((j['bloklar'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaBlok.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        izinler: ((j['izinler'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaIzinBlok.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        toplamSaat: (j['toplam_saat'] as num?)?.toDouble() ?? 0,
        hedefSaat: (j['hedef_saat'] as num?)?.toDouble() ?? 0,
      );
}

class VardiyaCizelge {
  const VardiyaCizelge({this.personel = const []});

  final List<VardiyaCizelgeKisi> personel;

  factory VardiyaCizelge.fromJson(Map<String, dynamic> j) => VardiyaCizelge(
        personel: ((j['personel'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaCizelgeKisi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// Toplu eklemenin sonucu.
///
/// `uygulandi=false` => HICBIR SEY YAZILMADI: cakisma var ve kullanici
/// henuz karar vermedi. Cakisan gunler `cakisanGunler`de.
class VardiyaTopluSonuc {
  const VardiyaTopluSonuc({
    required this.uygulandi,
    required this.eklenen,
    required this.cakisan,
    this.cakisanGunler = const [],
    this.uyarilar = const [],
  });

  final bool uygulandi;
  final int eklenen;
  final int cakisan;
  final List<String> cakisanGunler;
  final List<String> uyarilar;

  factory VardiyaTopluSonuc.fromJson(Map<String, dynamic> j) {
    final gunler = ((j['gunler'] as List?) ?? const []).whereType<Map>();
    return VardiyaTopluSonuc(
      uygulandi: (j['uygulandi'] as bool?) ?? true,
      eklenen: (j['eklenen'] as int?) ?? 0,
      cakisan: (j['cakisan'] as int?) ?? 0,
      cakisanGunler: gunler
          .where((g) => g['durum'] == 'cakisma')
          .map((g) => (g['tarih'] as String?) ?? '')
          .toList(),
      uyarilar: ((j['uyarilar'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// (P232) Bir vardiya DILIMI — "Gece 22:00-06:00".
///
/// Sunucudaki `VardiyaDilim` ile birebir. Gece/gunduz "kalibi" ZATEN bu
/// kavramdir (P207); ikinci bir kavram uretilmedi.
class VardiyaDilim {
  const VardiyaDilim({
    required this.ad,
    required this.baslangic,
    required this.bitis,
  });

  final String ad;
  final String baslangic;
  final String bitis;

  Map<String, dynamic> toJson() => {
    'ad': ad,
    'baslangic': baslangic,
    'bitis': bitis,
  };
}

/// (P232) BIR GUN GRUBU + o gruba uygulanacak dilimler.
///
/// "Pazartesi gunduz, sali-carsamba gece" TEK istekte gonderilir: gruplar
/// ayri ayri yazilsaydi geri alma birden cok istek olurdu — kullanici
/// acisindan tek karar, sistemde birden cok iz.
class VardiyaGunGrubu {
  const VardiyaGunGrubu({
    required this.gunler,
    required this.dilimler,
    required this.atamalar,
  });

  /// `yyyy-MM-dd` — DUZENSIZ olabilir, aralik DEGIL.
  final List<String> gunler;
  final List<VardiyaDilim> dilimler;

  /// dilim sirasi -> personel kimlikleri.
  final Map<int, List<String>> atamalar;

  Map<String, dynamic> toJson() => {
    'gunler': gunler,
    'dilimler': [for (final d in dilimler) d.toJson()],
    // Sunucu anahtarlari DIZGE bekliyor (JSON nesne anahtari).
    'atamalar': {
      for (final e in atamalar.entries) e.key.toString(): e.value,
    },
  };
}

/// (P232) `kalip-uygula` yaniti — onizleme ve uygulama AYNI sekli doner.
class VardiyaKalipSonuc {
  const VardiyaKalipSonuc({
    required this.uygulandi,
    required this.eklenecek,
    required this.eklenen,
    required this.cakisan,
    required this.zatenVar,
    this.partiId,
  });

  final bool uygulandi;
  final int eklenecek;
  final int eklenen;
  final int cakisan;
  final int zatenVar;

  /// Geri alma icin (P207). Onizlemede null.
  final String? partiId;

  factory VardiyaKalipSonuc.fromJson(Map<String, dynamic> json) =>
      VardiyaKalipSonuc(
        uygulandi: json['uygulandi'] as bool? ?? false,
        eklenecek: (json['eklenecek'] as num?)?.toInt() ?? 0,
        eklenen: (json['eklenen'] as num?)?.toInt() ?? 0,
        cakisan: (json['cakisan'] as num?)?.toInt() ?? 0,
        zatenVar: (json['zaten_var'] as num?)?.toInt() ?? 0,
        partiId: json['parti_id'] as String?,
      );
}

// =========================================================================== //
// (P247 §1) VARDIYA DONGUSU (ROTASYON)
// =========================================================================== //

/// Kayitli kalip. `adimlar` doluysa DONGUDUR (gun uzunlugunda adim dizisi;
/// her adim o gunun dilim sira numaralari, bos = tatil).
class VardiyaKalibi {
  const VardiyaKalibi({
    required this.id,
    required this.ad,
    required this.dilimler,
    this.adimlar,
  });

  final String id;
  final String ad;
  final List<VardiyaDilim> dilimler;
  final List<List<int>>? adimlar;

  bool get donguMu => adimlar != null;

  factory VardiyaKalibi.fromJson(Map<String, dynamic> j) => VardiyaKalibi(
    id: j['id'] as String,
    ad: j['ad'] as String,
    dilimler: (j['dilimler'] as List? ?? const [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .map((m) => VardiyaDilim(
              ad: m['ad'] as String,
              baslangic: (m['baslangic'] as String).substring(0, 5),
              bitis: (m['bitis'] as String).substring(0, 5),
            ))
        .toList(),
    adimlar: (j['adimlar'] as List?)
        ?.map((a) => (a as List).map((x) => x as int).toList())
        .toList(),
  );
}

/// Onizleme/sonuc satiri: gun x kisi x dilim + durum.
class VardiyaDonguSatiri {
  const VardiyaDonguSatiri({
    required this.tarih,
    required this.dilim,
    required this.userId,
    required this.durum,
  });

  final String tarih;
  final String dilim;
  final String userId;

  /// eklenecek | eklendi | cakisma | zaten_var | izinli
  final String durum;

  factory VardiyaDonguSatiri.fromJson(Map<String, dynamic> j) =>
      VardiyaDonguSatiri(
        tarih: j['tarih'] as String,
        dilim: j['dilim'] as String,
        userId: j['user_id'] as String,
        durum: j['durum'] as String,
      );
}

/// Bir gunun kimsesiz saat araliklari (sunucu hesaplar).
class VardiyaKapsamaGunu {
  const VardiyaKapsamaGunu({
    required this.tarih,
    required this.bosDakika,
    required this.bosluklar,
  });

  final String tarih;
  final int bosDakika;

  /// "00:00-08:00" bicimli araliklar.
  final List<String> bosluklar;

  factory VardiyaKapsamaGunu.fromJson(Map<String, dynamic> j) =>
      VardiyaKapsamaGunu(
        tarih: j['tarih'] as String,
        bosDakika: (j['bos_dakika'] as num).toInt(),
        bosluklar: (j['bosluklar'] as List? ?? const [])
            .map((m) => Map<String, dynamic>.from(m as Map))
            .map((m) =>
                '${(m['baslangic'] as String).substring(0, 5)}-${(m['bitis'] as String).substring(0, 5)}')
            .toList(),
      );
}

class VardiyaDonguSonuc {
  const VardiyaDonguSonuc({
    required this.uygulandi,
    required this.partiId,
    required this.bitis,
    required this.eklenecek,
    required this.eklenen,
    required this.cakisan,
    required this.izinli,
    required this.satirlar,
    required this.kapsama,
  });

  final bool uygulandi;
  final String? partiId;
  final String bitis;
  final int eklenecek;
  final int eklenen;
  final int cakisan;
  final int izinli;
  final List<VardiyaDonguSatiri> satirlar;
  final List<VardiyaKapsamaGunu> kapsama;

  List<VardiyaKapsamaGunu> get bosGunler =>
      kapsama.where((k) => k.bosDakika > 0).toList();

  factory VardiyaDonguSonuc.fromJson(Map<String, dynamic> j) =>
      VardiyaDonguSonuc(
        uygulandi: j['uygulandi'] as bool,
        partiId: j['parti_id'] as String?,
        bitis: j['bitis'] as String,
        eklenecek: (j['eklenecek'] as num? ?? 0).toInt(),
        eklenen: (j['eklenen'] as num? ?? 0).toInt(),
        cakisan: (j['cakisan'] as num? ?? 0).toInt(),
        izinli: (j['izinli'] as num? ?? 0).toInt(),
        satirlar: (j['satirlar'] as List? ?? const [])
            .map((m) =>
                VardiyaDonguSatiri.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        kapsama: (j['kapsama'] as List? ?? const [])
            .map((m) =>
                VardiyaKapsamaGunu.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

class VardiyaDonguAtama {
  const VardiyaDonguAtama({
    required this.id,
    required this.ad,
    required this.kalipAd,
    required this.partiId,
    required this.durum,
    required this.uretildiKadar,
    required this.atlanan,
  });

  final String id;
  final String ad;
  final String kalipAd;
  final String partiId;
  final String durum;
  final String? uretildiKadar;
  final int atlanan;

  factory VardiyaDonguAtama.fromJson(Map<String, dynamic> j) =>
      VardiyaDonguAtama(
        id: j['id'] as String,
        ad: (j['ad'] as String?) ?? '',
        kalipAd: (j['kalip_ad'] as String?) ?? '',
        partiId: j['parti_id'] as String,
        durum: j['durum'] as String,
        uretildiKadar: j['uretildi_kadar'] as String?,
        atlanan: (j['atlanan'] as List? ?? const []).length,
      );
}
