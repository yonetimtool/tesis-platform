/// (P253 Asama 2) TANIMLAR — TEK GENEL DEFTER, ALAN LISTESIYLE SURULUR.
///
/// Web `admin-web/components/tanimlar/tanimlar.tsx` (DEFTERLER) ile AYNI
/// desen: defter basina ayri ekran YAZILMAZ. Her defter bir uc + alan
/// listesidir; liste, form ve silme tek bilesenden (`GenelDefterScreen`)
/// gelir. Alan adlari, turleri ve zorunluluk web tanimiyla bire bir.
///
/// UC ADRESLERI LITERAL DIZEDIR (`uc: '/kasalar'`): mobil eylem taramasi
/// (`test/helpers/eylem_tarama.dart`) `DefterTanimi(` bloklarindaki `uc`
/// dizesini GET/POST + `{id}` PATCH/DELETE olarak acar — web'in genel
/// vekil acilimiyla (`genelAcilim`) ayni fikir. Degiskenle kurulan bir yol
/// taramadan kacardi.
library;

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/girdi_siniri.dart';

enum AlanTuru { metin, iban, telefon, eposta, sayi, kurus, tarih, bool_, secim, referans }

class AlanSecenegi {
  const AlanSecenegi(this.deger, this.etiket);
  final String deger;
  final String Function(AppLocalizations l10n) etiket;
}

class DefterAlani {
  const DefterAlani({
    required this.ad,
    required this.etiket,
    required this.tur,
    this.zorunlu = false,
    this.secenekler = const [],
    this.ipucu,
    this.ozet = false,
    this.referansUcu,
    this.referansEtiketi,
    this.ozetAlani,
    this.sadeceOlustur = false,
    this.azami,
    this.buyukHarf = false,
  });

  final String ad;
  final String Function(AppLocalizations l10n) etiket;
  final AlanTuru tur;
  final bool zorunlu;
  final List<AlanSecenegi> secenekler;
  final String Function(AppLocalizations l10n)? ipucu;

  /// Liste kartinin alt satirinda gosterilsin mi (web `sutun`).
  final bool ozet;

  /// `referans` icin: secenekleri yukleyen uc (literal) ve etiket alani.
  final String? referansUcu;
  final String? referansEtiketi;

  /// Kartta gosterilecek alan, formdakinden farkli olabilir (`unit_id`
  /// yerine sunucunun cozdugu `unit_no`).
  final String? ozetAlani;

  /// Yalniz olusturmada gonderilir — sunucu PATCH govdesinde kabul etmez.
  final bool sadeceOlustur;

  /// Sunucu `max_length`i; verilmezse ture gore.
  final int? azami;

  /// IBAN, evrak seri gibi buyuk harfli kodlar.
  final bool buyukHarf;

  int get enFazla =>
      azami ??
      switch (tur) {
        AlanTuru.iban => GirdiSiniri.iban,
        AlanTuru.eposta => GirdiSiniri.eposta,
        AlanTuru.kurus => GirdiSiniri.tutar,
        AlanTuru.sayi => GirdiSiniri.sayi,
        AlanTuru.telefon => 30,
        _ => GirdiSiniri.ad,
      };
}

class DefterTanimi {
  const DefterTanimi({
    required this.kimlik,
    required this.uc,
    required this.baslik,
    required this.alanlar,
    required this.adAlani,
    this.otomatikSayac = false,
  });

  /// Rota parametresi (`?defter=kasalar`) — web `?defter=` ile ayni ad.
  final String kimlik;

  /// Sunucu ucu (LITERAL — bkz. dosya basi).
  final String uc;
  final String Function(AppLocalizations l10n) baslik;
  final List<DefterAlani> alanlar;

  /// Kartin basligi ve silme onayindaki kayit adi.
  final String adAlani;

  /// Bolum sayaclari: "ana sayac icin tum dairelere sayac ac".
  final bool otomatikSayac;
}

DefterAlani _aktif() =>
    DefterAlani(ad: 'aktif', etiket: (l) => l.tnmAlanAktif, tur: AlanTuru.bool_);

final defterler = <DefterTanimi>[
  DefterTanimi(
    kimlik: 'kasalar',
    uc: '/kasalar',
    baslik: (l) => l.tnmKasalar,
    adAlani: 'ad',
    alanlar: [
      DefterAlani(ad: 'kod', etiket: (l) => l.tnmAlanKod, tur: AlanTuru.metin, zorunlu: true, ozet: true, azami: 20),
      DefterAlani(ad: 'ad', etiket: (l) => l.tnmAlanAd, tur: AlanTuru.metin, zorunlu: true),
      DefterAlani(ad: 'acilis_tarihi', etiket: (l) => l.tnmAlanAcilisTarihi, tur: AlanTuru.tarih),
      DefterAlani(ad: 'acilis_bakiye_kurus', etiket: (l) => l.tnmAlanAcilisBakiye, tur: AlanTuru.kurus, ozet: true),
      DefterAlani(ad: 'banka_mi', etiket: (l) => l.tnmAlanBankaMi, tur: AlanTuru.bool_),
      DefterAlani(ad: 'iban', etiket: (l) => l.tnmAlanIban, tur: AlanTuru.iban, buyukHarf: true),
      DefterAlani(ad: 'banka_adi', etiket: (l) => l.tnmAlanBankaAdi, tur: AlanTuru.metin),
      DefterAlani(ad: 'sube', etiket: (l) => l.tnmAlanSube, tur: AlanTuru.metin),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'gelir-gider-gruplari',
    uc: '/gelir-gider-gruplari',
    baslik: (l) => l.tnmGelirGiderGruplari,
    adAlani: 'ad',
    alanlar: [
      DefterAlani(ad: 'ad', etiket: (l) => l.tnmAlanAd, tur: AlanTuru.metin, zorunlu: true),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'gelir-gider-tanimlari',
    uc: '/gelir-gider-tanimlari',
    baslik: (l) => l.tnmGelirGiderTanimlari,
    adAlani: 'ad',
    alanlar: [
      DefterAlani(ad: 'ad', etiket: (l) => l.tnmAlanAd, tur: AlanTuru.metin, zorunlu: true),
      DefterAlani(
        ad: 'tip',
        etiket: (l) => l.tnmAlanTip,
        tur: AlanTuru.secim,
        zorunlu: true,
        ozet: true,
        secenekler: [
          AlanSecenegi('gelir', (l) => l.tnmTipGelir),
          AlanSecenegi('gider', (l) => l.tnmTipGider),
          AlanSecenegi('her_ikisi', (l) => l.tnmTipHerIkisi),
        ],
      ),
      DefterAlani(
        ad: 'dagitim_sekli',
        etiket: (l) => l.tnmAlanDagitim,
        tur: AlanTuru.secim,
        secenekler: [
          AlanSecenegi('bagimsiz_bolumlere_esit', (l) => l.tnmDagitimEsit),
          AlanSecenegi('tipe_gore', (l) => l.tnmDagitimTipeGore),
        ],
      ),
      DefterAlani(
        ad: 'hedef_kurali',
        etiket: (l) => l.tnmAlanHedefKurali,
        tur: AlanTuru.secim,
        ozet: true,
        ipucu: (l) => l.tnmHedefKuraliIpucu,
        secenekler: [
          AlanSecenegi('kiraci_oncelikli', (l) => l.tnmHedefKullanan),
          AlanSecenegi('malik', (l) => l.tnmHedefMalik),
        ],
      ),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'firmalar',
    uc: '/firmalar',
    baslik: (l) => l.tnmFirmalar,
    adAlani: 'ad',
    alanlar: [
      DefterAlani(ad: 'ad', etiket: (l) => l.tnmAlanAd, tur: AlanTuru.metin, zorunlu: true, azami: 200),
      DefterAlani(ad: 'vergi_no', etiket: (l) => l.tnmAlanVergiNo, tur: AlanTuru.metin, ozet: true, azami: 11),
      DefterAlani(ad: 'vergi_dairesi', etiket: (l) => l.tnmAlanVergiDairesi, tur: AlanTuru.metin),
      DefterAlani(ad: 'telefon', etiket: (l) => l.tnmAlanTelefon, tur: AlanTuru.telefon, ozet: true),
      DefterAlani(ad: 'email', etiket: (l) => l.tnmAlanEposta, tur: AlanTuru.eposta),
      DefterAlani(ad: 'yetkili_ad', etiket: (l) => l.tnmAlanYetkili, tur: AlanTuru.metin, azami: 150),
      DefterAlani(ad: 'acilis_bakiye_kurus', etiket: (l) => l.tnmAlanAcilisBakiye, tur: AlanTuru.kurus),
      DefterAlani(
        ad: 'acilis_bakiye_yon',
        etiket: (l) => l.tnmAlanBakiyeYonu,
        tur: AlanTuru.secim,
        secenekler: [
          AlanSecenegi('borc', (l) => l.tnmYonBorc),
          AlanSecenegi('alacak', (l) => l.tnmYonAlacak),
        ],
      ),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'arac-kayitlari',
    uc: '/arac-kayitlari',
    baslik: (l) => l.tnmAraclar,
    adAlani: 'plaka',
    alanlar: [
      DefterAlani(ad: 'plaka', etiket: (l) => l.tnmAlanPlaka, tur: AlanTuru.metin, zorunlu: true, azami: 30, buyukHarf: true),
      DefterAlani(ad: 'marka', etiket: (l) => l.tnmAlanMarka, tur: AlanTuru.metin, ozet: true, azami: 50),
      DefterAlani(ad: 'model', etiket: (l) => l.tnmAlanModel, tur: AlanTuru.metin, ozet: true, azami: 50),
      DefterAlani(ad: 'renk', etiket: (l) => l.tnmAlanRenk, tur: AlanTuru.metin, azami: 30),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'sayaclar-ana',
    uc: '/sayaclar/ana',
    baslik: (l) => l.tnmSayaclar,
    adAlani: 'ad',
    alanlar: [
      DefterAlani(ad: 'ad', etiket: (l) => l.tnmAlanAd, tur: AlanTuru.metin, zorunlu: true),
      DefterAlani(
        ad: 'tip',
        etiket: (l) => l.tnmAlanTip,
        tur: AlanTuru.secim,
        ozet: true,
        secenekler: [
          AlanSecenegi('su', (l) => l.tnmSayacSu),
          AlanSecenegi('elektrik', (l) => l.tnmSayacElektrik),
          AlanSecenegi('dogalgaz', (l) => l.tnmSayacDogalgaz),
          AlanSecenegi('isi', (l) => l.tnmSayacIsi),
          AlanSecenegi('diger', (l) => l.tnmSayacDiger),
        ],
      ),
      DefterAlani(ad: 'tesisat_no', etiket: (l) => l.tnmAlanTesisatNo, tur: AlanTuru.metin, azami: 50),
      DefterAlani(ad: 'ortak_alan_yuzde', etiket: (l) => l.tnmAlanOrtakAlanYuzde, tur: AlanTuru.sayi, ozet: true),
      _aktif(),
    ],
  ),
  DefterTanimi(
    kimlik: 'sayaclar-bolum',
    uc: '/sayaclar/bolum',
    baslik: (l) => l.tnmSayaclarBolum,
    adAlani: 'unit_no',
    otomatikSayac: true,
    alanlar: [
      DefterAlani(
        ad: 'unit_id',
        etiket: (l) => l.tnmAlanDaire,
        tur: AlanTuru.referans,
        zorunlu: true,
        referansUcu: '/units',
        referansEtiketi: 'no',
        ozetAlani: 'unit_no',
        sadeceOlustur: true,
      ),
      DefterAlani(
        ad: 'ana_sayac_id',
        etiket: (l) => l.tnmAlanAnaSayac,
        tur: AlanTuru.referans,
        ozet: true,
        referansUcu: '/sayaclar/ana',
        referansEtiketi: 'ad',
        ozetAlani: 'ana_sayac_ad',
      ),
      DefterAlani(ad: 'tesisat_no', etiket: (l) => l.tnmAlanTesisatNo, tur: AlanTuru.metin, ozet: true, azami: 50),
      DefterAlani(ad: 'ilk_okuma', etiket: (l) => l.tnmAlanIlkOkuma, tur: AlanTuru.sayi),
      _aktif(),
    ],
  ),
];

DefterTanimi? defterBul(String? kimlik) {
  for (final d in defterler) {
    if (d.kimlik == kimlik) return d;
  }
  return null;
}
