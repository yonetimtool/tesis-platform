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

  String get saatAraligi => '${_ss(baslar)}–${_ss(biter)}';

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
      );
}

class VardiyaCizelgeKisi {
  const VardiyaCizelgeKisi({
    required this.userId,
    required this.ad,
    required this.rol,
    this.bloklar = const [],
  });

  final String userId;
  final String ad;
  final String rol;
  final List<VardiyaBlok> bloklar;

  factory VardiyaCizelgeKisi.fromJson(Map<String, dynamic> j) =>
      VardiyaCizelgeKisi(
        userId: j['user_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
        bloklar: ((j['bloklar'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => VardiyaBlok.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
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
