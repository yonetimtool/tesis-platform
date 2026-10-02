// (P250 §9) OTOMASYON KURALLARI — DUZ CUMLE.
//
// Her kural ekranda TEK BIR CUMLE olarak okunur: "Her ayin 1. gunu tum
// dairelere daire basina 750,00 ₺ “Aidat” borcu yazilir ...". Teknik
// terim (tahakkuk, kademe, periyot, dagitim) cumleye GIRMEZ.
//
// Saf fonksiyonlar: `t` ve bicimleyiciler disaridan gelir; testler
// cumleyi sayfayi cizmeden olcer.
import { kurusToTL } from "@/lib/money";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";

export type Ceviri = (a: SozlukAnahtari, p?: Record<string, string | number>) => string;

export interface PlanKurali {
  id: string;
  ad: string;
  gelir_gider_tanim_id: string;
  dagitim: string;
  tutar_kurus: number | null;
  toplam_tutar_kurus: number | null;
  tahakkuk_gunu: number;
  vade_gun: number;
  onizleme_gun: number;
  aktif: boolean;
  son_donem: string | null;
  ertelenen_donem: string | null;
}

export interface GiderKurali {
  id: string;
  ad: string;
  tutar_kurus: number;
  periyot: string;
  sonraki_tarih: string;
  otomatik_onay: boolean;
  aktif: boolean;
  kasa_id: string | null;
}

export interface HatirlatmaKurali {
  aktif: boolean;
  vade_oncesi_gun: number;
  kademeler: number[];
  metin: string | null;
  eposta: boolean;
  ilk_gun: number | null;
  tekrar_sayisi: number;
  aralik_gun: number | null;
}

export interface GecikmeKurali {
  gecikme_aylik_yuzde: number;
  gecikme_uygula: boolean;
}

export interface SonCalisma {
  kural: string;
  tur: string;
  zaman: string;
  adet: number;
  tutar_kurus: number;
  durum: string | null;
}

export const SIKLIK: Record<string, SozlukAnahtari> = {
  aylik: "otoKuralSiklikAylik",
  uc_aylik: "otoKuralSiklikUcAylik",
  alti_aylik: "otoKuralSiklikAltiAylik",
  yillik: "otoKuralSiklikYillik",
};

export const PAYLASIM: Record<string, SozlukAnahtari> = {
  daire_basina: "otoSihirbazPaylasimDaire",
  esit: "otoSihirbazPaylasimEsit",
  arsa_payi: "otoSihirbazPaylasimArsa",
  metrekare: "otoSihirbazPaylasimMetrekare",
};

const PAYLASIM_CUMLE: Record<string, SozlukAnahtari> = {
  esit: "otoKuralPaylasimEsit",
  arsa_payi: "otoKuralPaylasimArsa",
  metrekare: "otoKuralPaylasimMetrekare",
};

export function planCumlesi(
  p: Pick<PlanKurali, "ad" | "dagitim" | "tutar_kurus" | "toplam_tutar_kurus" | "tahakkuk_gunu" | "vade_gun">,
  t: Ceviri,
): string {
  const ortak = { gun: p.tahakkuk_gunu, ad: p.ad, vade: p.vade_gun };
  if (p.dagitim === "daire_basina") {
    return t("otoKuralPlanCumle", { ...ortak, tutar: kurusToTL(p.tutar_kurus ?? 0) });
  }
  return t("otoKuralPlanCumleToplam", {
    ...ortak,
    tutar: kurusToTL(p.toplam_tutar_kurus ?? 0),
    paylasim: t(PAYLASIM_CUMLE[p.dagitim] ?? PAYLASIM_CUMLE.esit),
  });
}

export function giderCumlesi(
  g: Pick<GiderKurali, "ad" | "tutar_kurus" | "periyot" | "sonraki_tarih" | "otomatik_onay">,
  t: Ceviri,
  tarih: (iso: string) => string,
): string {
  return t("otoKuralGiderCumle", {
    siklik: t(SIKLIK[g.periyot] ?? SIKLIK.aylik),
    ad: g.ad,
    tutar: kurusToTL(g.tutar_kurus),
    onay: t(g.otomatik_onay ? "otoKuralGiderOtomatik" : "otoKuralGiderOnayBekler"),
    tarih: tarih(g.sonraki_tarih),
  });
}

/** (P250 §7) Hatirlatmanin cumlesi — GERCEK kademelerle. */
export function hatirlatmaCumlesi(a: HatirlatmaKurali, t: Ceviri, dil: string): string {
  if (!a.aktif || a.kademeler.length === 0) return t("otoHatirlatmaKapali");
  const gunler = new Intl.ListFormat(dil, { type: "conjunction" }).format(
    a.kademeler.map(String),
  );
  const kanal = a.eposta ? t("otoKanalBildirimEposta") : t("otoKanalBildirim");
  const ana = t("otoHatirlatmaCumle", { gunler, kanal });
  return a.vade_oncesi_gun > 0
    ? `${ana} ${t("otoHatirlatmaVadeOncesiCumle", { gun: a.vade_oncesi_gun })}`
    : ana;
}

/** (P252 §2) Maas otomasyonunun durumu — `GET /otomasyon/maas-ayari`. */
export interface MaasKurali {
  aktif: boolean;
  otomatik_onay: boolean;
  gruplar: { odeme_gunu: number; personel_sayisi: number; aylik_toplam_kurus: number }[];
  personel_sayisi: number;
  aylik_toplam_kurus: number;
  onay_bekleyenler: { id: string; tarih: string; aciklama: string | null; tutar_kurus: number }[];
}

/** "Her ayin 5. gunu 3 personelin maasi (toplam 75.000 ₺) gidere yazilir."
 *  Odeme gunu basina bir cumle; personel yoksa ne yapilacagini soyler. */
export function maasCumlesi(m: MaasKurali, t: Ceviri): string {
  if (m.gruplar.length === 0) return t("otoKuralMaasYok");
  return m.gruplar
    .map((g) =>
      t("otoKuralMaasCumle", {
        gun: g.odeme_gunu,
        adet: g.personel_sayisi,
        tutar: kurusToTL(g.aylik_toplam_kurus),
      }),
    )
    .join(" ");
}

export function gecikmeCumlesi(g: GecikmeKurali, t: Ceviri): string {
  if (!g.gecikme_uygula || g.gecikme_aylik_yuzde <= 0) return t("otoKuralGecikmeKapali");
  return t("otoKuralGecikmeCumle", { oran: g.gecikme_aylik_yuzde });
}

/** Son calismanin cumlesi; hic calismadiysa "Henuz calismadi". */
export function sonCalismaCumlesi(
  s: SonCalisma | undefined,
  t: Ceviri,
  zaman: (iso: string) => string,
): string {
  if (!s) return t("otoKuralSonYok");
  const z = zaman(s.zaman);
  if (s.durum === "ertelendi") return t("otoKuralSonErtelendi", { zaman: z });
  const tutar = kurusToTL(s.tutar_kurus);
  switch (s.tur) {
    case "aidat_tahakkuk":
      return t("otoKuralSonPlan", { zaman: z, adet: s.adet, tutar });
    case "duzenli_gider":
      return t("otoKuralSonGider", { zaman: z });
    case "borc_hatirlatma":
      return t("otoKuralSonHatirlatma", { zaman: z, adet: s.adet });
    case "gecikme_faizi":
      return t("otoKuralSonGecikme", { zaman: z, adet: s.adet, tutar });
    // (P252 §2) Maas otomasyonu.
    case "maas":
      return t("otoKuralSonMaas", { zaman: z, adet: s.adet, tutar });
    default:
      return t("otoKuralSonYok");
  }
}
