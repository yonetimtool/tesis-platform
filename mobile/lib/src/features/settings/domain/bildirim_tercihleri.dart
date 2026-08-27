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
  });

  final bool eposta;
  final bool sms;
  final bool mobil;

  factory BildirimTercihleri.fromJson(Map<String, dynamic> json) {
    return BildirimTercihleri(
      eposta: json['bildirim_eposta'] as bool? ?? true,
      sms: json['bildirim_sms'] as bool? ?? true,
      mobil: json['bildirim_mobil'] as bool? ?? true,
    );
  }

  BildirimTercihleri copyWith({bool? eposta, bool? sms, bool? mobil}) {
    return BildirimTercihleri(
      eposta: eposta ?? this.eposta,
      sms: sms ?? this.sms,
      mobil: mobil ?? this.mobil,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BildirimTercihleri &&
      other.eposta == eposta &&
      other.sms == sms &&
      other.mobil == mobil;

  @override
  int get hashCode => Object.hash(eposta, sms, mobil);
}
