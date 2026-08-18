// (P167 §5) RAPOR MODALI — alan sozlugu.
//
// =========================================================================
// GOREV BOLUMU: SUNUCU "HANGI ALANLAR", ISTEMCI "NASIL CIZILIR"
// =========================================================================
// Katalog her rapor icin `alanlar: string[]` doner — o raporun GERCEKTEN
// anlamlandirdigi `RaporParametre` alanlari. Bu dosya o adlarin her birinin
// EKRANDA nasil gorunecegini soyler: tarih secici mi, acilir liste mi,
// onay kutusu mu, ve etiketi hangi sozluk anahtari.
//
// LISTEYI ISTEMCIDE TUTMADIK. "Hangi raporun hangi alani var" bilgisi
// istemcide ikinci kez yazilsaydi, bir rapora yeni suzgec eklendiginde iki
// yer ayrisirdi ve kusur SESSIZ olurdu: alan cizilir, kullanici doldurur,
// sunucu yok sayar, kimse fark etmez — ta ki cikti yanlis gelene kadar.
//
// TERSI DE DOGRU: "nasil cizilir" sunucuda tutulsaydi, backend bir form
// kutuphanesi tarif etmeye baslardi ve arayuz degistiginde sozlesme
// degismek zorunda kalirdi.
//
// =========================================================================
// TANIMSIZ ALAN SESSIZCE ATLANMAZ
// =========================================================================
// Katalog burada karsiligi olmayan bir alan adi dondururse, `alanCiz`
// `null` doner ve `tests/rapor-alanlari.test.ts` bunu KIRMIZI yapar.
// Sessizce atlamak, sunucunun sundugu bir suzgeci kullaniciya hic
// gostermemek olurdu.

import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/** Alanin ekranda aldigi bicim. */
export type AlanTuru =
  | "tarih"
  | "metin"
  | "sayi"
  | "kurus"
  | "onay"
  | "ay"
  | "yil"
  | "kasa"
  | "firma"
  | "kisi"
  | "daire"
  | "tanim"
  | "tanimCoklu"
  | "secim";

export interface AlanTanimi {
  tur: AlanTuru;
  etiket: SozlukAnahtari;
  /** `secim` icin sabit degerler; bos deger "hepsi" anlamina gelir. */
  secenekler?: { id: string; etiket: SozlukAnahtari }[];
  /** Varsayilan `true` olan onay kutulari (KVKK anahtari gibi). */
  varsayilanAcik?: boolean;
}

/**
 * `RaporParametre` alan adi -> ekran tanimi.
 *
 * Anahtarlar backend'in `RaporParametre` alan adlariyla BIREBIR aynidir;
 * govde dogrudan bu adlarla kurulur. Ara bir eslestirme katmani (orn.
 * `baslangicTarihi` -> `baslangic`) iki isimlendirme dunyasi yaratir ve
 * hangisinin dogru oldugunu her seferinde aramak gerekirdi.
 */
export const ALAN_TANIMLARI: Record<string, AlanTanimi> = {
  baslangic: { tur: "tarih", etiket: "raporBaslangic" },
  bitis: { tur: "tarih", etiket: "raporBitis" },
  tazminat_tarihi: { tur: "tarih", etiket: "raporTazminatTarihi" },
  blok: { tur: "metin", etiket: "raporBlok" },
  kasa_id: { tur: "kasa", etiket: "raporKasa" },
  firma_id: { tur: "firma", etiket: "raporFirma" },
  user_id: { tur: "kisi", etiket: "raporKisi" },
  unit_id: { tur: "daire", etiket: "raporDaire" },
  olusturan_user_id: { tur: "kisi", etiket: "raporOlusturan" },
  gelir_gider_tanim_id: { tur: "tanim", etiket: "raporTanim" },
  // BRIEF "Borclandirma Turu 1..5 (bes ayri alan)" diyor — o bir MODAL
  // YERLESIMIDIR; veri bir LISTEDIR. Bes ayri alan adi acmak, altincisi
  // istendiginde sozlesmeyi degistirmek zorunda birakirdi.
  gelir_gider_tanim_idler: { tur: "tanimCoklu", etiket: "raporTanimlar" },
  bolum: { tur: "metin", etiket: "raporBolum" },
  min_tutar_kurus: { tur: "kurus", etiket: "raporMinTutar" },
  max_tutar_kurus: { tur: "kurus", etiket: "raporMaxTutar" },
  baslangic_ay: { tur: "ay", etiket: "raporBaslangicAy" },
  baslangic_yil: { tur: "yil", etiket: "raporBaslangicYil" },
  bitis_ay: { tur: "ay", etiket: "raporBitisAy" },
  bitis_yil: { tur: "yil", etiket: "raporBitisYil" },
  ismi_goster: { tur: "onay", etiket: "raporIsmiGoster", varsayilanAcik: true },
  icradakileri_goster: {
    tur: "onay",
    etiket: "raporIcradakiler",
    varsayilanAcik: true,
  },
  aciklamalari_goster: {
    tur: "onay",
    etiket: "raporAciklamalar",
    varsayilanAcik: true,
  },
  evrak_bilgisi_goster: {
    tur: "onay",
    etiket: "raporEvrakBilgisi",
    varsayilanAcik: true,
  },
  grup_goster: { tur: "onay", etiket: "raporGrupla" },
  /** (P168 §3) VARSAYILAN KAPALI: telefon ve e-posta kisisel veridir ve
   *  kapiya asilacak bir listede varsayilan olarak bulunmamali. */
  iletisim_goster: { tur: "onay", etiket: "raporIletisimGoster" },
  imza: { tur: "onay", etiket: "raporImza" },
  listeleme_tipi: {
    tur: "secim",
    etiket: "raporListelemeTipi",
    secenekler: [
      { id: "borclu", etiket: "raporTipBorclu" },
      { id: "alacakli", etiket: "raporTipAlacakli" },
    ],
  },
  ekstre_turu: {
    tur: "secim",
    etiket: "raporEkstreTuru",
    secenekler: [
      { id: "ozet", etiket: "raporEkstreOzet" },
      { id: "detay", etiket: "raporEkstreDetay" },
    ],
  },
  evrak_tipi: {
    tur: "secim",
    etiket: "raporEvrakTipi",
    secenekler: [
      { id: "makbuz", etiket: "raporEvrakMakbuz" },
      { id: "fatura", etiket: "raporEvrakFatura" },
    ],
  },
  calisma_sekli: {
    tur: "secim",
    etiket: "raporCalismaSekli",
    secenekler: [
      { id: "tahakkuk", etiket: "raporCalismaTahakkuk" },
      { id: "nakit", etiket: "raporCalismaNakit" },
    ],
  },
  siralama: {
    tur: "secim",
    etiket: "raporSiralama",
    secenekler: [
      { id: "unit", etiket: "raporSiraDaire" },
      { id: "ad", etiket: "raporSiraAd" },
      { id: "bakiye", etiket: "raporSiraBakiye" },
    ],
  },
};

/** Kategori kimligi -> bolum basligi. Sira SUNUCUDAN gelir (`kategoriler`). */
export const KATEGORI_BASLIGI: Record<string, SozlukAnahtari> = {
  listeler: "raporKatListeler",
  ekstreler: "raporKatEkstreler",
  dokumler: "raporKatDokumler",
};

/** Kategori kimligi -> `IkonKutu` vurgu rengi. Kategoriyi yalniz baslikla
 *  ayirmak, uzun bir izgarada kaydirirken hangi bolumde olundugunu
 *  kaybettirirdi. */
export const KATEGORI_VURGUSU: Record<string, "blue" | "green" | "purple"> = {
  listeler: "blue",
  ekstreler: "green",
  dokumler: "purple",
};

/** Is durumu -> rozet metni. */
export const DURUM_ETIKETI: Record<string, SozlukAnahtari> = {
  bekliyor: "raporIsBekliyor",
  uretiliyor: "raporIsUretiliyor",
  hazir: "raporIsHazir",
  hata: "raporIsHata",
};

/** `YYYY-AA-GG` — tarih girdisinin bekledigi bicim. */
function gun(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/**
 * (P168 §3) TARIH VARSAYILANLARI: Ilk Tarih = YILBASI, Son Tarih = BUGUN.
 *
 * Brief'in acik istegi. Gerekcesi de saglam: raporlarin ezici cogunlugu
 * "bu yil ne oldu" sorusunu sorar. Bos birakmak, kullaniciyi her rapor
 * icin iki tarih doldurmaya zorlar; daha kotusu, zorunlu alanlari bos
 * birakip "Goster"e basinca dogrulama hatasi almasina yol acardi.
 *
 * YALNIZ DONEM ALANLARI: `tazminat_tarihi` DOLDURULMAZ — o "hangi
 * tarihe gore gecikme hesaplansin" sorusudur ve sunucu bos birakildiginda
 * `bitis`i, o da yoksa bugunu kullanir (P31). Onu da yilbasi yapsaydik,
 * tazminati YILIN BASINA gore hesaplatmis olurduk: sessizce yanlis rakam.
 */
export function baslangicDegeri(ad: string): string | boolean | string[] {
  const tanim = ALAN_TANIMLARI[ad];
  if (!tanim) return "";
  if (tanim.tur === "onay") return tanim.varsayilanAcik === true;
  if (tanim.tur === "tanimCoklu") return [];
  if (ad === "baslangic") {
    const simdi = new Date();
    return gun(new Date(Date.UTC(simdi.getUTCFullYear(), 0, 1)));
  }
  if (ad === "bitis") return gun(new Date());
  return "";
}

/** Bir raporun alanlari icin baslangic durumu. */
export function baslangicDurumu(
  alanlar: string[],
): Record<string, string | boolean | string[]> {
  const d: Record<string, string | boolean | string[]> = {};
  for (const ad of alanlar) d[ad] = baslangicDegeri(ad);
  return d;
}

/**
 * Form durumunu `RaporParametre` govdesine cevirir.
 *
 * BOS ALAN GONDERILMEZ — ama `false` GONDERILIR: `ismi_goster: false`
 * KVKK'nin ta kendisidir ve "bos" sayilip dusurulseydi, ad sutununu
 * kaldirmak isteyen kullanici adlari basili gorurdu.
 */
export function govdeyeCevir(
  durum: Record<string, string | boolean | string[]>,
): Record<string, unknown> {
  const govde: Record<string, unknown> = {};
  for (const [ad, deger] of Object.entries(durum)) {
    const tanim = ALAN_TANIMLARI[ad];
    if (!tanim) continue;
    if (typeof deger === "boolean") {
      govde[ad] = deger;
      continue;
    }
    if (Array.isArray(deger)) {
      if (deger.length > 0) govde[ad] = deger;
      continue;
    }
    if (deger === "") continue;
    if (tanim.tur === "kurus") {
      // TL girilir, KURUS gonderilir: sunucu her yerde kurus konusur ve
      // istisna acmak, bir raporda 100 TL'yi 1 TL saymak olurdu.
      const sayi = Number(deger.replace(",", "."));
      if (Number.isFinite(sayi)) govde[ad] = Math.round(sayi * 100);
      continue;
    }
    if (tanim.tur === "ay" || tanim.tur === "yil" || tanim.tur === "sayi") {
      const sayi = Number(deger);
      if (Number.isFinite(sayi)) govde[ad] = sayi;
      continue;
    }
    govde[ad] = deger;
  }
  return govde;
}
