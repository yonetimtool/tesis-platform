/// (P253 Asama 2) TESIS OPERASYON AYARLARI — web `admin-web/lib/tesis-ayar-
/// alanlari.ts` `OPERASYON` tablosunun mobil ikizi.
///
/// AYNI SIRA, AYNI SINIRLAR: sinirlar sunucudaki `TenantSettingsUpdate`
/// alanlari ve DDL `CHECK`leriyle ayni. Burada dar bir aralik yazmak,
/// sunucunun kabul ettigi degeri telefonda reddetmek olurdu.
///
/// `adminOnly` alanlar (guvenlik modu) mobilde HIC YOK: web de yalniz
/// platform admininde cizer; yonetici yazamaz (sunucu 403).
///
/// Kilit: `test/p253_tesis_ayarlari_test.dart` web tablosundaki
/// `anahtar` kumesini bu tabloyla karsilastirir — biri eklenip oteki
/// unutulursa duser.
library;

import '../../../../l10n/gen/app_localizations.dart';

enum AyarTipi { sayi, bool, metin, secim }

enum AyarGrubu { devriye, vardiya, gurultu, finans, rezervasyon, otopark }

class AyarSecenegi {
  const AyarSecenegi(this.deger, this.etiket);
  final String deger;
  final String Function(AppLocalizations) etiket;
}

class TesisAyari {
  const TesisAyari({
    required this.grup,
    required this.anahtar,
    required this.etiket,
    required this.tip,
    this.ipucu,
    this.min,
    this.max,
    this.azami,
    this.secenekler = const [],
  });

  final AyarGrubu grup;

  /// Sunucu alan adi (`/tenant/settings`).
  final String anahtar;
  final String Function(AppLocalizations) etiket;
  final String Function(AppLocalizations)? ipucu;
  final AyarTipi tip;
  final int? min;
  final int? max;

  /// `metin` alanin sunucu `max_length`i.
  final int? azami;
  final List<AyarSecenegi> secenekler;
}

String ayarGrubuBasligi(AppLocalizations l, AyarGrubu g) => switch (g) {
      AyarGrubu.devriye => l.tsaAyarGrupDevriye,
      AyarGrubu.vardiya => l.tsaAyarGrupVardiya,
      AyarGrubu.gurultu => l.tsaAyarGrupGurultu,
      AyarGrubu.finans => l.tsaAyarGrupFinans,
      AyarGrubu.rezervasyon => l.tsaAyarGrupRezervasyon,
      AyarGrubu.otopark => l.tsaAyarGrupOtopark,
    };

/// Web `OPERASYON` (adminOnly HARIC) — ayni sira.
final List<TesisAyari> tesisAyarlari = [
  TesisAyari(
    grup: AyarGrubu.devriye,
    anahtar: 'tur_gecikme_toleransi_dk',
    etiket: (l) => l.tsaAyarTurTolerans,
    ipucu: (l) => l.tsaAyarTurToleransIpucu,
    tip: AyarTipi.sayi,
    min: 1,
    max: 240,
  ),
  TesisAyari(
    grup: AyarGrubu.devriye,
    anahtar: 'tur_alarm_tekrar_sayisi',
    etiket: (l) => l.tsaAyarTurTekrar,
    ipucu: (l) => l.tsaAyarTurTekrarIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 10,
  ),
  TesisAyari(
    grup: AyarGrubu.devriye,
    anahtar: 'tur_baslangic_foto_zorunlu',
    etiket: (l) => l.tsaAyarTurFoto,
    ipucu: (l) => l.tsaAyarTurFotoIpucu,
    tip: AyarTipi.bool,
  ),
  TesisAyari(
    grup: AyarGrubu.vardiya,
    anahtar: 'vardiya_hatirlatma_dk',
    etiket: (l) => l.tsaAyarVardiyaHatirlatma,
    ipucu: (l) => l.tsaAyarVardiyaHatirlatmaIpucu,
    // METIN: kademe listesi ("30,5"); bos = kapali (web ile ayni).
    tip: AyarTipi.metin,
    azami: 40,
  ),
  TesisAyari(
    grup: AyarGrubu.vardiya,
    anahtar: 'vardiya_baslamadi_dk',
    etiket: (l) => l.tsaAyarVardiyaBaslamadi,
    ipucu: (l) => l.tsaAyarVardiyaBaslamadiIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 180,
  ),
  TesisAyari(
    grup: AyarGrubu.devriye,
    anahtar: 'okutma_mesafe_esigi_m',
    etiket: (l) => l.tsaAyarOkutmaMesafe,
    ipucu: (l) => l.tsaAyarOkutmaMesafeIpucu,
    tip: AyarTipi.sayi,
    min: 1,
    max: 5000,
  ),
  TesisAyari(
    grup: AyarGrubu.otopark,
    anahtar: 'otopark_kapasite',
    etiket: (l) => l.tsaAyarOtoparkKapasite,
    ipucu: (l) => l.tsaAyarOtoparkKapasiteIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 100000,
  ),
  TesisAyari(
    grup: AyarGrubu.rezervasyon,
    anahtar: 'rezervasyon_gecmis_ay',
    etiket: (l) => l.tsaAyarRezervasyonGecmis,
    ipucu: (l) => l.tsaAyarRezervasyonGecmisIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 120,
  ),
  TesisAyari(
    grup: AyarGrubu.finans,
    anahtar: 'varsayilan_hedef_kurali',
    etiket: (l) => l.tsaAyarVarsayilanHedef,
    ipucu: (l) => l.tsaAyarVarsayilanHedefIpucu,
    tip: AyarTipi.secim,
    secenekler: [
      AyarSecenegi('kiraci_oncelikli', (l) => l.tsaTanimHedefKullanan),
      AyarSecenegi('malik', (l) => l.tsaTanimHedefMalik),
    ],
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_esigi',
    etiket: (l) => l.tsaAyarGurultuEsigi,
    ipucu: (l) => l.tsaAyarGurultuEsigiIpucu,
    tip: AyarTipi.sayi,
    min: 1,
    max: 50,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_uyari_metni',
    etiket: (l) => l.tsaAyarGurultuMetni,
    ipucu: (l) => l.tsaAyarGurultuMetniIpucu,
    tip: AyarTipi.metin,
    azami: 1000,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_pencere_gun',
    etiket: (l) => l.tsaAyarGurultuPencere,
    ipucu: (l) => l.tsaAyarGurultuPencereIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 365,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_susma_gun',
    etiket: (l) => l.tsaAyarGurultuSusma,
    ipucu: (l) => l.tsaAyarGurultuSusmaIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 365,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_eskalasyon_esigi',
    etiket: (l) => l.tsaAyarGurultuEskalasyon,
    ipucu: (l) => l.tsaAyarGurultuEskalasyonIpucu,
    tip: AyarTipi.sayi,
    min: 1,
    max: 10,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'sikayet_harita_saat',
    etiket: (l) => l.tsaAyarHaritaSaat,
    ipucu: (l) => l.tsaAyarHaritaSaatIpucu,
    tip: AyarTipi.sayi,
    min: 0,
    max: 8760,
  ),
  TesisAyari(
    grup: AyarGrubu.gurultu,
    anahtar: 'gurultu_sakin_uyarisi',
    etiket: (l) => l.tsaAyarGurultuSakin,
    ipucu: (l) => l.tsaAyarGurultuSakinIpucu,
    tip: AyarTipi.bool,
  ),
];
