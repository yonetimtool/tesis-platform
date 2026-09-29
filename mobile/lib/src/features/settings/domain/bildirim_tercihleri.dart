/// (P183 §5) Isleyis bildirimlerinin KANAL tercihleri — sunucu tarafi
/// (`GET/PATCH /me/bildirim-tercihleri`, goc 0055). Pazarlama rizasindan
/// (KVKK) AYRIDIR: pazarlama bir riza (varsayilan kapali), bildirim bir
/// tercih (varsayilan acik). `bildirim_mobil` kapaliyken backend mobil push
/// GONDERMEZ — ama uygulama ici bildirim listesi ETKILENMEZ.
class BildirimTercihleri {
  const BildirimTercihleri({
    required this.eposta,
    required this.sms,
    required this.mobil,
    this.sesli = true,
    this.yonetimArayabilir = false,
  });

  final bool eposta;
  final bool sms;
  final bool mobil;

  /// (P207 §2) SESLI UYARI. `mobil`den AYRI soru: bildirim gelsin mi
  /// DEGIL, SESLI mi gelsin. Ikisini tek anahtara baglamak, "gece
  /// caliyor" diyen kullaniciya bildirimin TAMAMINI kapattirirdi.
  final bool sesli;

  /// (P249 §3e) "Yonetim beni bu numaradan arayabilir" — varsayilan KAPALI.
  final bool yonetimArayabilir;

  factory BildirimTercihleri.fromJson(Map<String, dynamic> json) {
    return BildirimTercihleri(
      eposta: json['bildirim_eposta'] as bool? ?? true,
      sms: json['bildirim_sms'] as bool? ?? true,
      mobil: json['bildirim_mobil'] as bool? ?? true,
      sesli: json['bildirim_sesi'] as bool? ?? true,
      yonetimArayabilir: json['yonetim_arayabilir'] as bool? ?? false,
    );
  }

  BildirimTercihleri copyWith({
    bool? eposta,
    bool? sms,
    bool? mobil,
    bool? sesli,
    bool? yonetimArayabilir,
  }) {
    return BildirimTercihleri(
      eposta: eposta ?? this.eposta,
      sms: sms ?? this.sms,
      mobil: mobil ?? this.mobil,
      sesli: sesli ?? this.sesli,
      yonetimArayabilir: yonetimArayabilir ?? this.yonetimArayabilir,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BildirimTercihleri &&
      other.eposta == eposta &&
      other.sms == sms &&
      other.mobil == mobil &&
      other.sesli == sesli &&
      other.yonetimArayabilir == yonetimArayabilir;

  @override
  int get hashCode => Object.hash(eposta, sms, mobil, sesli, yonetimArayabilir);
}
