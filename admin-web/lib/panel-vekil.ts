/**
 * P40 panel bolumu — BFF vekil BEYAZ LISTESI.
 *
 * NEDEN `lib`DE, route.ts ICINDE DEGIL: Next.js yol isleyicileri yalnizca
 * HTTP metotlarini ve belirli yapilandirma degerlerini disa aktarabilir;
 * baska bir `export` derleme hatasidir (P27'de `npm run build` yakalamisti,
 * `tsc --noEmit` yakalamamisti).
 *
 * NEDEN TEK VEKIL: P40 yirmiden fazla backend ucunu panele acar. Her biri
 * icin ayri `route.ts` yazmak ayni on satiri yirmi kez kopyalamak olurdu ve
 * biri guncellenip digeri unutulurdu (P27'nin `[kaynak]` deseni ayni
 * gerekceyle secilmisti).
 *
 * NEDEN BEYAZ LISTE (ve neden "onek eslesmesi" DEGIL): istemciden gelen ad
 * hicbir zaman dogrudan URL'e girmez. `/finans/...` gibi bir onek kurali
 * yeterli GORUNUR ama `finans/../users` ya da `finans/hareketler?x=..#/`
 * gibi girdilerle asilmaya calisilir; tam eslesen bir sozluk bu sinifi
 * tumden ortadan kaldirir.
 */

/** Panelin GET ile okudugu kaynaklar: ad -> backend yolu. */
export const OKUMA: Record<string, string> = {
  // --- finans (P28/P29) ---
  "kasa-bakiyeleri": "/finans/kasa-bakiyeleri",
  "finans-hareketler": "/finans/hareketler",
  "finans-ozet": "/finans/ozet",
  "icra-dosyalari": "/finans/icra-dosyalari",
  // --- rapor (P31) ---
  "rapor-katalog": "/raporlar/katalog",
  // --- mesaj (P32) ---
  "mesaj-sablonlari": "/mesaj-sablonlari",
  "mesaj-gecmis": "/mesajlar/gecmis",
  // --- yonetisim (P33) ---
  "karar-defteri": "/karar-defteri",
  dokumanlar: "/dokumanlar",
  "site-aktar-sablon": "/site-aktar/sablon",
  // --- KVKK (P36) ---
  "kvkk-metinler": "/kvkk/metinler",
  // --- gurultu (P37) ---
  "unit-uyarilari": "/unit-uyarilari",
  // --- portal + anket (P38) ---
  portal: "/portal",
  "portal-galeri": "/portal/galeri",
  "portal-iletisim": "/portal/iletisim",
  anketler: "/anketler",
  // --- yetki matrisi (P41) — SALT OKUMA ---
  "yetki-matrisi": "/yetki-matrisi",
};

/** POST ile YAZILAN kaynaklar (okumadan AYRI: bir ucu yanlislikla yazmaya
 *  acmak, okumaya acmaktan cok daha pahali bir hata olurdu). */
export const YAZMA: Record<string, string> = {
  "finans-hareketler": "/finans/hareketler",
  "finans-tahsilat": "/finans/tahsilat",
  "finans-virman": "/finans/virman",
  "finans-iade": "/finans/iade",
  "banka-eslestir": "/finans/banka-eslestir",
  "icra-dosyalari": "/finans/icra-dosyalari",
  "mesaj-sablonlari": "/mesaj-sablonlari",
  "mesaj-onizleme": "/mesajlar/onizleme",
  "mesaj-gonder": "/mesajlar/gonder",
  "karar-defteri": "/karar-defteri",
  dokumanlar: "/dokumanlar",
  "site-aktar": "/site-aktar",
  "kvkk-metin": "/kvkk/metin",
  anketler: "/anketler",
  "portal-galeri": "/portal/galeri",
};

/** Kaynak basina ILETILEBILEN sorgu parametreleri (yine beyaz liste:
 *  gelisiguzel parametre gecirmek, backend'de var olmayan bir suzgeci
 *  varmis gibi gostermek ya da beklenmedik bir dal acmak olurdu). */
export const SUZGECLER: Record<string, string[]> = {
  "finans-hareketler": ["tip", "kasa_id", "baslangic", "bitis"],
  "mesaj-sablonlari": ["kanal", "aktif"],
  "mesaj-gecmis": ["kanal", "durum"],
  "unit-uyarilari": ["unit_id"],
  "karar-defteri": [],
  anketler: [],
};

export function okumaYolu(kaynak: string): string | null {
  return OKUMA[kaynak] ?? null;
}

export function yazmaYolu(kaynak: string): string | null {
  return YAZMA[kaynak] ?? null;
}


/** Rapor cikti bicimleri (P31). Beyaz liste: `bicim` sorgu parametresi
 *  dogrudan backend'e gider ve serbest birakmak, var olmayan bir bicim
 *  icin sunucudan hata almak yerine panelde sessiz bir bos yanit
 *  gostermek olurdu. */
export const RAPOR_BICIMLERI: string[] = ["tablo", "excel", "pdf"];
