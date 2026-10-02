// (P251 §6) ICE AKTARIM ALANLARI — okunur ad + rol secenekleri.
//
// Tablo basliklari ve hata satirlari HAM ALAN KODUNU gosteriyordu
// ("sakin_ad", "rol_tipi"). Kod sunucu ile istemci arasindaki ANLASMADIR
// ve degismez; ekranda ise kullanicinin dilinde ad gorunur. Sozlukte
// karsiligi olmayan (yeni eklenmis) bir kod OLDUGU GIBI gosterilir —
// sessizce bos kalmasin, eksik ceviri fark edilsin.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";

type Ceviri = (a: SozlukAnahtari) => string;

const ETIKET: Record<string, SozlukAnahtari> = {
  blok: "iceAktarimAlan_blok",
  daire_no: "iceAktarimAlan_daire_no",
  arsa_payi: "iceAktarimAlan_arsa_payi",
  metrekare: "iceAktarimAlan_metrekare",
  ad: "iceAktarimAlan_ad",
  soyad: "iceAktarimAlan_soyad",
  eposta: "iceAktarimAlan_eposta",
  telefon: "iceAktarimAlan_telefon",
  rol_tipi: "iceAktarimAlan_rol_tipi",
  plaka: "iceAktarimAlan_plaka",
  arac_marka: "iceAktarimAlan_arac_marka",
  arac_model: "iceAktarimAlan_arac_model",
  tutar: "iceAktarimAlan_tutar",
  aciklama: "iceAktarimAlan_aciklama",
  // Daire turundeki sakin sutunlari ayni anlamda: "sakin_ad" -> "Ad".
  sakin_ad: "iceAktarimAlan_ad",
  sakin_soyad: "iceAktarimAlan_soyad",
  sakin_eposta: "iceAktarimAlan_eposta",
  sakin_telefon: "iceAktarimAlan_telefon",
};

export function alanEtiketi(t: Ceviri, kod: string): string {
  const a = ETIKET[kod];
  return a ? t(a) : kod;
}

/** Rol sutunu (malik / kiraci / malik_oturan) acilir listedir. */
export function rolSutunuMu(kod: string): boolean {
  return kod === "rol_tipi";
}

export const ROL_TIPI_SECENEKLERI: readonly (readonly [string, SozlukAnahtari])[] = [
  ["malik", "iceAktarimRolMalik"],
  ["kiraci", "iceAktarimRolKiraci"],
  ["malik_oturan", "iceAktarimRolMalikOturan"],
];

/**
 * Yapistirilan/yazilan rol metnini koda cevirir: Excel'de insanlar
 * "Kiracı", "malik-oturan", "Malik Oturan" yazar. Sunucu `-`yi `_`ye
 * ceviriyordu ama Turkce `ı`yi ve buyuk harfi taniyamiyordu; acilir liste
 * de taninmayan metni gosteremez. Taninmazsa HAM deger kalir — sunucu
 * satiri `gecersiz_rol_tipi` ile isaretler (sessizce duzeltilmez).
 */
export function rolTipiNormalle(ham: string): string {
  const s = ham
    .trim()
    .toLocaleLowerCase("tr-TR")
    // Noktasiz kucuk i (U+0131) -> i. Kacisla yazildi: kaynakta Turkce
    // harf tasimak `i18n` kaynak taramasina takiliyor.
    .replace(/\u0131/g, "i")
    .replace(/[\s-]+/g, "_");
  if (s === "malik" || s === "kiraci" || s === "malik_oturan") return s;
  if (s === "malik_ve_oturan" || s === "ev_sahibi_oturan") return "malik_oturan";
  if (s === "ev_sahibi") return "malik";
  return ham.trim();
}
