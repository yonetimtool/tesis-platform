/// (P202) Sunucunun guncelleme karari.
library;

/// Uc seviye. KIMLIK, metin degil: uygulama buna gore dallanir.
enum SurumDurumu {
  /// Hicbir sey gosterilmez.
  guncel,

  /// Kapatilabilir uyari; kullanici devam edebilir.
  onerilen,

  /// Uygulama KULLANILAMAZ; kapatilamayan ekran.
  zorunlu,
}

class SurumKarari {
  const SurumKarari({
    required this.durum,
    this.mesaj,
    this.magazaUrl,
  });

  final SurumDurumu durum;

  /// Operatorun yazdigi metin (sunucu dile gore secer). BOS olabilir —
  /// o zaman uygulama KENDI yerellestirilmis metnini gosterir.
  final String? mesaj;

  /// Platforma gore magaza adresi. Sunucudan gelir; istemcide
  /// SABITLENMEZ (adres degisirse eski istemciler tam "guncelle"
  /// derken kirik bir dugmeye basardi).
  final String? magazaUrl;

  factory SurumKarari.fromJson(Map<String, dynamic> j) {
    final ham = (j['durum'] as String?) ?? 'guncel';
    return SurumKarari(
      // BILINMEYEN DEGER "guncel" SAYILIR: sunucu bir gun yeni bir
      // seviye eklerse ESKI istemci kullaniciyi kilitlememeli.
      durum: switch (ham) {
        'zorunlu' => SurumDurumu.zorunlu,
        'onerilen' => SurumDurumu.onerilen,
        _ => SurumDurumu.guncel,
      },
      mesaj: (j['mesaj'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['mesaj'] as String).trim(),
      magazaUrl: (j['magaza_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['magaza_url'] as String).trim(),
    );
  }
}
