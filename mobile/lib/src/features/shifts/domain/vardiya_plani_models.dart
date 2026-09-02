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
