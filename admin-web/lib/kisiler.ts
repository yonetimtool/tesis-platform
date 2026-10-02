// (P251 §8) KISILER SAYFASININ SEKMELERI — tek kaynak.
//
// Sayfa (`app/(protected)/kisiler`), eski adres yonlendirmeleri ve
// testler ayni listeyi okur. Sayfa dosyasi Next.js kurali geregi ek
// disa aktarim tasiyamaz; liste bu yuzden burada.
import type { UserRole } from "@/lib/types";

export const KISILER_SEKMELERI = ["sakinler", "personel", "yoneticiler", "davetler"] as const;
export type KisilerSekmesi = (typeof KISILER_SEKMELERI)[number];

/** Sekme -> liste kapsami. Personel = uc saha rolu (P231). */
export const SEKME_KAPSAMI: Record<Exclude<KisilerSekmesi, "davetler">, readonly UserRole[]> = {
  sakinler: ["resident"],
  personel: ["security", "tesis_gorevlisi", "guvenlik_amiri"],
  yoneticiler: ["yonetici", "denetci"],
};

/** Eski `/users?rol=..` -> sekme. */
export function rolunSekmesi(rol: string): KisilerSekmesi {
  if (rol === "resident") return "sakinler";
  if (rol === "yonetici" || rol === "denetci") return "yoneticiler";
  return "personel";
}
