// (P250 §6) HIZLI ISLEMLER — istemci esleme: kimlik -> rota, etiket, ikon.
//
// Hangi rolun hangi islemi GOREBILECEGI sunucuda (`backend/app/hizli_islem.py`
// KATALOG); bu dosya yalniz "kimlik neye benzer, nereye gider" sorusunu
// yanitlar. Sunucunun bilmedigi kimlik burada olsa bile listede CIKMAZ
// (secenekler sunucudan gelir). Mobil esi:
// `mobile/lib/src/features/home/domain/hizli_islemler.dart` — ayni kimlikler.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export type HizliIslem = { rota: string; anahtar: SozlukAnahtari; ikon: string };

export const HIZLI_ISLEM_KATALOGU: Record<string, HizliIslem> = {
  aidat: { rota: "/dues", anahtar: "panoHizliAidat", ikon: "M12 3v18M16 7.5C16 6 14.2 5 12 5S8 6 8 7.5 9.8 10 12 10s4 1 4 2.5S14.2 15 12 15s-4-1-4-2.5" },
  talep: { rota: "/complaints", anahtar: "panoHizliTalep", ikon: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" },
  duyuru: { rota: "/announcements", anahtar: "panoHizliDuyuru", ikon: "M3 11v2a1 1 0 0 0 1 1h3l5 4V6L7 10H4a1 1 0 0 0-1 1ZM16 8a5 5 0 0 1 0 8" },
  personel: { rota: "/kisiler?sekme=personel", anahtar: "panoHizliPersonel", ikon: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM19 8v6M22 11h-6" },
  sakin: { rota: "/kisiler?sekme=sakinler", anahtar: "panoHizliSakin", ikon: "M3 21V10l9-7 9 7v11M9 21v-6h6v6" },
  gorev: { rota: "/tasks", anahtar: "panoHizliGorev", ikon: "M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9" },
  ziyaretci: { rota: "/ziyaretciler", anahtar: "panoHizliZiyaretci", ikon: "M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M15 12H3" },
  borclular: { rota: "/finans/borclular", anahtar: "panoHizliBorclular", ikon: "M12 8v4l3 3M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" },
  gider: { rota: "/finans/giderler", anahtar: "panoHizliGider", ikon: "M12 21V3M5 10l7-7 7 7" },
  rezervasyon: { rota: "/rezervasyon-yonetimi", anahtar: "panoHizliRezervasyon", ikon: "M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z" },
  vardiya: { rota: "/vardiya-plani", anahtar: "panoHizliVardiya", ikon: "M12 6v6l4 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z" },
  anket: { rota: "/anketler", anahtar: "panoHizliAnket", ikon: "M9 17V9M13 17V5M17 17v-4M3 21h18" },
  rapor: { rota: "/raporlar", anahtar: "panoHizliRapor", ikon: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M8 13h8M8 17h5" },
  kurulum: { rota: "/kurulum", anahtar: "panoHizliKurulum", ikon: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" },
};

export const HIZLI_UST_SINIR = 8;

export type HizliIslemler = {
  secenekler: string[];
  secili: string[];
  varsayilan: string[];
  ozel: boolean;
};

/** Secimde bir ogeyi yukari (-1) / asagi (+1) tasir. Saf; test edilir. */
export function sirayiTasi(secim: readonly string[], kimlik: string, yon: -1 | 1): string[] {
  const i = secim.indexOf(kimlik);
  const j = i + yon;
  if (i < 0 || j < 0 || j >= secim.length) return [...secim];
  const yeni = [...secim];
  [yeni[i], yeni[j]] = [yeni[j], yeni[i]];
  return yeni;
}
