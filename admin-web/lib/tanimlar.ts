/**
 * P27 "Tanimlar" katmani — kaynak adi BEYAZ LISTESI.
 *
 * NEDEN `lib`DE, route.ts ICINDE DEGIL: Next.js yol isleyicileri yalnizca
 * HTTP metotlarini ve belirli yapilandirma degerlerini disa aktarabilir;
 * baska bir `export` derleme hatasidir (`npm run build` yakaladi, `tsc
 * --noEmit` yakalamamisti).
 *
 * NEDEN BEYAZ LISTE: istemciden gelen `kaynak` hicbir zaman dogrudan URL'e
 * girmez — aksi halde `/kasalar/../../users` gibi bir yol uydurulabilirdi.
 */
export const TANIM_KAYNAKLARI: Record<string, string> = {
  kasalar: "/kasalar",
  "gelir-gider-gruplari": "/gelir-gider-gruplari",
  "gelir-gider-tanimlari": "/gelir-gider-tanimlari",
  firmalar: "/firmalar",
  "personel-kayitlari": "/personel-kayitlari",
  "arac-kayitlari": "/arac-kayitlari",
  "sayaclar-ana": "/sayaclar/ana",
  "sayaclar-bolum": "/sayaclar/bolum",
};

/** Kaynak basina ILETILEBILEN sorgu parametreleri (yine beyaz liste). */
export const TANIM_SUZGECLERI: Record<string, string[]> = {
  "gelir-gider-tanimlari": ["tip"],
  "arac-kayitlari": ["plaka"],
  "sayaclar-bolum": ["ana_sayac_id", "unit_id"],
};

export function backendYolu(kaynak: string): string | null {
  return TANIM_KAYNAKLARI[kaynak] ?? null;
}
