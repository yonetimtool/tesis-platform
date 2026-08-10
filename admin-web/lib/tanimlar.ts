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
  // (P154 / Asama 7.1+7.2) DAIRE TIPLERI + GRUPLARI.
  //
  // Uclar (P26) VARDI, panelde EKRANI YOKTU — brief 7.2 bunu acikca
  // istiyor ("Bagimsiz bolum tanimlari" -> "Daire Tipleri", ayni sayfa
  // WEB'e) ve 7.1 menusunun TANIMLAR bolumu bu satiri sayiyor.
  //
  // AYRI BIR SAYFA YAZILMADI: `/tanimlar` zaten veri-surumlu defter
  // desenidir; iki satir eklemek, ikinci bir liste/form ekrani yazmaktan
  // hem kisa hem de tek-kaynak.
  "unit-tipleri": "/unit-tipleri",
  "unit-gruplari": "/unit-gruplari",
  kasalar: "/kasalar",
  "gelir-gider-gruplari": "/gelir-gider-gruplari",
  "gelir-gider-tanimlari": "/gelir-gider-tanimlari",
  firmalar: "/firmalar",
  "personel-kayitlari": "/personel-kayitlari",
  "arac-kayitlari": "/arac-kayitlari",
  "sayaclar-ana": "/sayaclar/ana",
  "sayaclar-bolum": "/sayaclar/bolum",
  // (P111) TOPLU URETIM — bir ana sayac icin TUM aktif dairelere sayac
  // acar. Ayri bir `route.ts` yerine ayni beyaz listeye girer: guvenlik
  // kurali (istemci yolu uydurmaz) tek yerde kalsin.
  "sayaclar-bolum-otomatik": "/sayaclar/bolum/otomatik",
};

/** Kaynak basina ILETILEBILEN sorgu parametreleri (yine beyaz liste). */
export const TANIM_SUZGECLERI: Record<string, string[]> = {
  "unit-tipleri": ["aktif"],
  "unit-gruplari": ["aktif"],
  "gelir-gider-tanimlari": ["tip"],
  "arac-kayitlari": ["plaka"],
  "sayaclar-bolum": ["ana_sayac_id", "unit_id"],
};

export function backendYolu(kaynak: string): string | null {
  return TANIM_KAYNAKLARI[kaynak] ?? null;
}
