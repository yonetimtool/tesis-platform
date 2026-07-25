/// Ana ekran bolumlerinin SAF gorunum modelleri — widget/provider/Dio YOK.
/// Hem [MockHomeRepository] (referans sabitleri) hem de gercek API'lerden
/// turetilen degerler bu tiplere donusur; bolum widget'lari YALNIZ bunlari
/// tanir. Boylece "gercek uca bagla" isi tek bir esleme fonksiyonu degistirir.
library;

import 'package:flutter/widgets.dart';

/// Baslik hava blogu ("☀ 24°C / İstanbul").
class HomeHava {
  const HomeHava({
    required this.sicaklik,
    required this.sehir,
    required this.ikon,
  });

  /// Bicimlenmis sicaklik, or. "24°C".
  final String sicaklik;
  final String sehir;
  final IconData ikon;
}

/// Hizli erisim karti (gorevli seridinde ve 4x2 izgarada AYNI kart).
class HizliErisimKart {
  const HizliErisimKart({
    required this.ikon,
    required this.baslik,
    required this.accent,
    required this.altMetin,
    this.altMetinRengi,
    this.ikinciAltMetin,
    this.ikinciAltMetinRengi,
    this.rota,
  });

  final IconData ikon;
  final String baslik;

  /// Ikon konteynerinin tint zemini + varsayilan alt metin rengi.
  final Color accent;

  /// Baslik altindaki sayac/etiket, or. "3 Aktif" / "Aylık Özet".
  ///
  /// **null = VERI HENUZ YOK** (gercek uc yukleniyor) → kart sayac satirinda
  /// iskelet cizer. UYDURMA SAYI YOKTUR: sozlesmede karsiligi olmayan
  /// kartlar 'Yakında' etiketi tasir (bkz. [MockHomeRepository]).
  final String? altMetin;

  /// Alt metin rengi — null ise [accent]. Referans gorsellerde SAYAC'lar
  /// accent, ACIKLAMA etiketleri ("Aylık Özet", "Bildirim Yap") gridir;
  /// hangisinin ne oldugu kart bazinda burada sabitlenir.
  final Color? altMetinRengi;

  /// Ikinci alt satir (yalniz "Aidat Bilgileri" karti: "Borç Yok").
  final String? ikinciAltMetin;
  final Color? ikinciAltMetinRengi;

  /// Dokununca gidilecek rota; null → karsiligi olmayan (mock) kart.
  final String? rota;

  /// Sayac metnini gercek veriyle degistirir (rota/ikon/renk korunur).
  HizliErisimKart sayacla(String? yeniAltMetin, {String? yeniIkinciAltMetin}) {
    if (yeniAltMetin == null && yeniIkinciAltMetin == null) return this;
    return HizliErisimKart(
      ikon: ikon,
      baslik: baslik,
      accent: accent,
      altMetin: yeniAltMetin ?? altMetin,
      altMetinRengi: altMetinRengi,
      ikinciAltMetin: yeniIkinciAltMetin ?? ikinciAltMetin,
      ikinciAltMetinRengi: ikinciAltMetinRengi,
      rota: rota,
    );
  }
}

/// "Son Hareketler" listesindeki tek satir.
///
/// Referans gorsellerde ikon rengi MODULUN rengidir (aidat=mavi cuzdan,
/// gurultu=kirmizi dalga), sagdaki nokta ise OLAYIN durum rengidir (yesil
/// olumlu, turuncu uyari...). Bu yuzden ikisi ayri alandir.
class HareketSatiri {
  const HareketSatiri({
    required this.ikon,
    required this.baslik,
    required this.altBaslik,
    required this.zaman,
    required this.ikonAccent,
    required this.noktaRengi,
    this.rota,
  });

  final IconData ikon;
  final String baslik;
  final String altBaslik;

  /// Hazir zaman etiketi, or. "09:32" / "Bugün 10:15" / "05.05.2026".
  final String zaman;

  final Color ikonAccent;
  final Color noktaRengi;
  final String? rota;
}

/// "Hızlı Özet" istatistik kutusu (yonetici).
class OzetKutusu {
  const OzetKutusu({
    required this.ikon,
    required this.deger,
    required this.etiket,
    required this.altEtiket,
    required this.accent,
    this.rota,
  });

  final IconData ikon;

  /// Buyuk deger, or. "52" / "₺750,00". **null = VERI HENUZ YOK** (gercek uc
  /// yukleniyor) → kutu iskelet cizer. Sozlesmede karsiligi olmayan kutu '—'
  /// tasir ve alt etiketi 'Yakında'dir.
  final String? deger;
  final String etiket;
  final String altEtiket;
  final Color accent;

  /// Dokununca gidilecek ekran; null → dokunma yok (mobilde ekrani olmayan
  /// kutu). Kutular ozetten DETAYA gecisin kisa yoludur.
  final String? rota;

  /// Buyuk degeri gercek veriyle degistirir (ikon/etiket/renk/rota korunur).
  /// [yeniDeger] null ise kutu YUKLENIYOR halinde kalir.
  OzetKutusu degerle(String? yeniDeger) => OzetKutusu(
        ikon: ikon,
        deger: yeniDeger ?? deger,
        etiket: etiket,
        altEtiket: altEtiket,
        accent: accent,
        rota: rota,
      );
}

/// Vardiya seridindeki tek kart (personel vardiyasi ya da yonetici karti).
class VardiyaKart {
  const VardiyaKart({
    required this.baslik,
    required this.altBaslik,
    required this.durum,
    required this.altBilgi,
    this.avatarUrl,
    this.online = false,
  });

  /// "Sabah Vardiyası" / "Yönetici".
  final String baslik;

  /// "06:00 - 14:00" / "Kerem Aşçı".
  final String altBaslik;

  final VardiyaDurum durum;

  /// Alt satir: "2 Görevli" ya da "Online".
  final String altBilgi;

  final String? avatarUrl;

  /// true → alt satir yesil nokta + metin ("● Online"); false → kisi ikonu.
  final bool online;
}

/// Vardiya kartinin durum cipi.
enum VardiyaDurum { aktif, planlandi, yonetici }

/// Sakin "Ödeme ve Aidat Durumu" karti — iki sutun.
class OdemeOzeti {
  const OdemeOzeti({
    required this.buAyTutar,
    required this.odendi,
    required this.sonOdeme,
    required this.gelecekTarih,
    required this.gelecekTutar,
  });

  /// "₺1.250,00".
  final String buAyTutar;

  /// true → yesil "Ödendi" cipi.
  final bool odendi;

  /// "05.05.2026".
  final String sonOdeme;
  final String gelecekTarih;
  final String gelecekTutar;
}

/// Duyuru karti ozeti.
class DuyuruOzeti {
  const DuyuruOzeti({
    required this.baslik,
    required this.govde,
    required this.tarih,
    required this.yeni,
    this.fotoUrl,
  });

  final String baslik;
  final String govde;

  /// "20 Mayıs – 09:00".
  final String tarih;

  /// true → mavi tint "Yeni" cipi.
  final bool yeni;

  /// null → gri yer tutucu kare (referans gorseldeki gibi).
  final String? fotoUrl;
}

/// Sakin ana ekraninin ICERIK bolumu satiri (Site Kuralları / Etkinlikler) —
/// duyuru kartiyla ayni desen: gorsel + baslik + ozet + tarih/cip.
class IcerikOzeti {
  const IcerikOzeti({
    required this.id,
    required this.baslik,
    required this.altMetin,
    required this.ikon,
    this.fotoUrl,
    this.tarih,
    this.cip,
    this.cipAccent,
  });

  /// Kaynak kaydin id'si (derin baglanti icin).
  final String id;

  final String baslik;

  /// Ikinci satir — kural icerigi ya da etkinlik aciklamasi (2 satir kirpma).
  final String altMetin;

  /// Gorsel yoksa yer tutucuda gorunecek ikon (kural/etkinlik ayrimi).
  final IconData ikon;

  /// Kisa omurlu presigned GET URL (sunucudan); yoksa yer tutucu.
  final String? fotoUrl;

  /// Bicimlenmis tarih satiri; null → satir cizilmez.
  final String? tarih;

  /// Sag alt cip ("Yaklaşan", "Sürüyor"...); null → cip yok.
  final String? cip;
  final Color? cipAccent;
}
