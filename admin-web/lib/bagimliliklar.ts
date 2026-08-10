import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 7.4) BAGIMLILIK HARITASI — tek kaynak.
 *
 * Brief: "Bir sey eklemek icin baska bir yerde tanimlama gerekiyorsa:
 * uyari cumlesi + ILGILI ALANA YONLENDIRME dugmesi, islem bitince geri
 * donus. TEK bilesen olarak kur, tum ekranlarda kullan."
 *
 * Girdi `docs/envanter.md` §0.4'teki 16 satirlik olcumdur. Her satir
 * "X eklemek icin once Y tanimlanmali" der ve bugun kullanicinin gordugu
 * sey ya BOS BIR ACILIR LISTE ya da anlamadigi bir **422**tir — ikisi de
 * "nereye gidecegini" soylemez.
 *
 * NEDEN VERI, NEDEN HER EKRANDA AYRI METIN DEGIL: ayni cumle ve ayni
 * hedef onlarca ekranda tekrarlanirdi; biri degistiginde otekiler eskirdi.
 * Bilesen (`components/BagimlilikUyarisi.tsx`) bu tablodan cizer.
 *
 * ROTA `sorgu` ILE AYRI TUTULUR — 7.1'deki menu ogesiyle AYNI SEBEP:
 * `rotaRoldeGorunur` TAM ESLESME yapar, sorguyu yola gomsek rol aramasi
 * bosa duserdi.
 */
export interface Bagimlilik {
  /** Uyari cumlesi (neyin eksik oldugu + neden gerekli). */
  mesaj: SozlukAnahtari;
  /** Dugme etiketi — "Kasa tanimla" gibi EYLEM cumlesi. */
  eylem: SozlukAnahtari;
  /** Gidilecek ekranin ROTASI (sorgu haric). */
  rota: string;
  /** Rotanin alt gorunumu (opsiyonel). */
  sorgu?: string;
}

export const BAGIMLILIKLAR = {
  // --- yapi ---
  blok: {
    mesaj: "bagimlilikBlok",
    eylem: "bagimlilikBlokEylem",
    rota: "/building-editor",
  },
  daire: {
    mesaj: "bagimlilikDaire",
    eylem: "bagimlilikDaireEylem",
    rota: "/building-editor",
  },
  daireTipi: {
    mesaj: "bagimlilikDaireTipi",
    eylem: "bagimlilikDaireTipiEylem",
    rota: "/tanimlar",
    sorgu: "defter=unit-tipleri",
  },
  // --- finans ---
  kasa: {
    mesaj: "bagimlilikKasa",
    eylem: "bagimlilikKasaEylem",
    rota: "/tanimlar",
    sorgu: "defter=kasalar",
  },
  ikinciKasa: {
    mesaj: "bagimlilikIkinciKasa",
    eylem: "bagimlilikKasaEylem",
    rota: "/tanimlar",
    sorgu: "defter=kasalar",
  },
  gelirGiderTanimi: {
    mesaj: "bagimlilikGelirGider",
    eylem: "bagimlilikGelirGiderEylem",
    rota: "/tanimlar",
    sorgu: "defter=gelir-gider-tanimlari",
  },
  // --- operasyon ---
  gorevKategorisi: {
    mesaj: "bagimlilikGorevKategori",
    eylem: "bagimlilikGorevKategoriEylem",
    rota: "/tasks",
  },
  nfcNoktasi: {
    mesaj: "bagimlilikNfc",
    eylem: "bagimlilikNfcEylem",
    rota: "/checkpoints",
  },
  mesajSablonu: {
    mesaj: "bagimlilikSablon",
    eylem: "bagimlilikSablonEylem",
    rota: "/mesajlar",
  },
} as const satisfies Record<string, Bagimlilik>;

export type BagimlilikKodu = keyof typeof BAGIMLILIKLAR;

/** Sorgu adi: "isini bitirince NEREYE donecegiz". */
export const DONUS_PARAM = "donus";

/**
 * Hedef baglanti + donus bilgisi.
 *
 * DONUS ADRESI SORGUDA TASINIR, tarayici gecmisinde DEGIL: kullanici
 * hedef ekranda birkac adim gezinebilir (defter sekmesi degistirir, form
 * acar) ve `history.back()` onu isini bitirdigi yere DEGIL bir onceki
 * karesine gonderirdi.
 *
 * ADRES DOGRULANIR: yalniz uygulama ici, tek egik cizgiyle baslayan yollar
 * kabul edilir. Aksi hâlde `?donus=https://baska-site` yazan biri
 * panelden disari yonlendiren bir dugme uretebilirdi (acik yonlendirme).
 */
export function hedefBaglantisi(b: Bagimlilik, donus: string | null): string {
  const temel = b.sorgu ? `${b.rota}?${b.sorgu}` : b.rota;
  const guvenli = gecerliDonus(donus);
  if (!guvenli) return temel;
  const ayirac = b.sorgu ? "&" : "?";
  return `${temel}${ayirac}${DONUS_PARAM}=${encodeURIComponent(guvenli)}`;
}

/** Uygulama ici bir yol mu? (acik yonlendirme korumasi) */
export function gecerliDonus(deger: string | null): string | null {
  if (!deger) return null;
  // `//host` ve `/\host` tarayicida MUTLAK adrestir — tek egik cizgi
  // kontrolu yetmez.
  if (!deger.startsWith("/") || deger.startsWith("//") || deger.startsWith("/\\")) {
    return null;
  }
  return deger;
}
