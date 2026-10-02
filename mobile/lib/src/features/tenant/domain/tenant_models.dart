/// Tesis (tenant) domain modelleri — `contracts/openapi.yaml` TenantSettings
/// semasina uyar.
library;

/// `GET /tenant/settings` yaniti. Mobil `ad`i ana ekran basliginda gosterir;
/// `kurulum_tamamlandi=false` ise BIRINCIL yonetici tesisi adlandirmalidir.
class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    required this.ad,
    this.kurulumTamamlandi = true,
    this.demoMod = false,
    this.adres,
    this.ilce,
    this.il,
    this.postaKodu,
  });

  /// (P251 §8) Tesis adresi — mobil Tesis ayarlari ekrani duzenler
  /// (web `/tesis-ayarlari` ile ayni alanlar; sunucu yoneticiye acik).
  final String? adres;
  final String? ilce;
  final String? il;
  final String? postaKodu;

  final String tenantId;
  final String ad;

  /// false ise BIRINCIL yonetici ILK GIRISTE tesisi adlandirmali (home gate).
  /// Eski/adlandirilmis tesislerde true.
  final bool kurulumTamamlandi;

  /// (P115) DEMO MODU — YALNIZ App Store denetim tesisinde true.
  ///
  /// Istemci bu bayragi YAZAMAZ, yalnizca OKUR: "simule okutma" dugmesi
  /// buna bakarak cizilir. Bayrak istemcide tutulsaydi herhangi bir
  /// kullanici GERCEK bir tesiste sahte tur kaydi uretebilirdi ve tur
  /// kaydinin KANIT degeri sifirlanirdi.
  final bool demoMod;

  factory TenantSettings.fromJson(Map<String, dynamic> json) => TenantSettings(
        tenantId: json['tenant_id'] as String,
        ad: json['ad'] as String? ?? '',
        kurulumTamamlandi: json['kurulum_tamamlandi'] as bool? ?? true,
        // Alan yoksa KAPALI: eski/bilinmeyen bir sunucuda demo dugmesini
        // cizmek, olmayan bir uca dokunduran olu bir dugme olurdu.
        demoMod: json['demo_mod'] as bool? ?? false,
        adres: json['adres'] as String?,
        ilce: json['ilce'] as String?,
        il: json['il'] as String?,
        postaKodu: json['posta_kodu'] as String?,
      );
}
