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
  // (P167 Asama 4) Sekiz sayfanin OKUDUGU uclar.
  "dues-assessments": "/dues/assessments",
  "kasalar": "/kasalar",
  "firmalar": "/firmalar",
  // --- rapor (P31) ---
  "rapor-katalog": "/raporlar/katalog",
  // --- mesaj (P32) ---
  "mesaj-sablonlari": "/mesaj-sablonlari",
  "mesaj-gecmis": "/mesajlar/gecmis",
  // (P173) EKSIKTI VE EKRANI TAMAMEN OLU BIRAKIYORDU.
  //
  // Backend'de `GET /mesaj-ayarlari` P168'den beri VAR; eksik olan bu
  // satirdi. Beyaz listede olmayan bir ad icin vekil kendi 404'unu
  // doner — sunucuya HIC gitmez, bu yuzden backend log'unda iz de yok.
  // Ekran cizili, alanlar bos, "Kaydet" kaydetmiyordu.
  "mesaj-ayarlari": "/mesaj-ayarlari",
  // --- yonetisim (P33) ---
  "karar-defteri": "/karar-defteri",
  dokumanlar: "/dokumanlar",
  // --- gurultu (P37) ---
  "unit-uyarilari": "/unit-uyarilari",
  // --- anket (P38) ---
  anketler: "/anketler",
  // --- yetki matrisi (P41) — SALT OKUMA ---
  "yetki-matrisi": "/yetki-matrisi",
  // --- not ve ek (P154 / Asama 6.4) ---
  // Ayri bir `route.ts` YAZILMADI: bu kaydin GET/POST/DELETE deseni tam
  // olarak `[kaynak]` ve `[kaynak]/[id]` isleyicilerinin yaptigi is.
  // Ucuncu bir vekil dosyasi ayni on satiri kopyalamak olurdu.
  ekler: "/ekler",
  // --- kurulum sihirbazi (P154 / Asama 7.3) ---
  kurulum: "/kurulum",
  // --- ice aktarim catisi (P154 / Asama 8) ---
  "ice-aktarim-turler": "/ice-aktarim/turler",
  "ice-aktarim": "/ice-aktarim",
  // --- (P192 §3.1) gecikme faizi ---
  "gecikme-ayari": "/borclandirma/gecikme-ayari",
  "gecikme-faizi-onizleme": "/borclandirma/gecikme-faizi/onizleme",
  // --- (P192 §4) otomasyon ---
  "aidat-planlari": "/aidat-planlari",
  "hatirlatma-ayari": "/hatirlatma-ayari",
  "duzenli-giderler": "/duzenli-giderler",
  "otomasyon-gunlugu": "/otomasyon-gunlugu",
};

/** POST ile YAZILAN kaynaklar (okumadan AYRI: bir ucu yanlislikla yazmaya
 *  acmak, okumaya acmaktan cok daha pahali bir hata olurdu). */
export const YAZMA: Record<string, string> = {
  "finans-hareketler": "/finans/hareketler",
  "finans-tahsilat": "/finans/tahsilat",
  "finans-virman": "/finans/virman",
  "finans-iade": "/finans/iade",
  // (P167 Asama 4) Brief'in sekiz sayfasinin ihtiyac duydugu, beyaz
  // listede eksik olan uclar. Yeni `route.ts` YAZILMADI: bu kayitlarin
  // GET/POST deseni tam olarak `[kaynak]` vekilinin yaptigi is.
  "finans-acilis": "/finans/acilis",
  "finans-tahsilat-toplu": "/finans/tahsilat/toplu",
  "borclandirma-toplu": "/borclandirma/toplu",
  "borclandirma-toplu-onizleme": "/borclandirma/toplu/onizleme",
  "dues-assessments": "/dues/assessments",
  "banka-eslestir": "/finans/banka-eslestir",
  "icra-dosyalari": "/finans/icra-dosyalari",
  "mesaj-sablonlari": "/mesaj-sablonlari",
  "mesaj-onizleme": "/mesajlar/onizleme",
  "mesaj-gonder": "/mesajlar/gonder",
  // (P173) Ayarlar TEKIL bir kaynak: PUT ile butun kayit yazilir.
  "mesaj-ayarlari": "/mesaj-ayarlari",
  "karar-defteri": "/karar-defteri",
  dokumanlar: "/dokumanlar",
  anketler: "/anketler",
  ekler: "/ekler",
  // PATCH hedefi kaynak KOKUDUR — sihirbaz adim atlamayi boyle yazar.
  kurulum: "/kurulum",
  // Ice aktarim: her TUR ayri bir beyaz liste girisi. Tur adini yola
  // dogrudan gecirmek, istemcinin `/ice-aktarim/../users` gibi bir yol
  // uydurabilmesi demekti (beyaz listenin varlik sebebi).
  "ice-aktarim-daire": "/ice-aktarim/daire",
  "ice-aktarim-kisi": "/ice-aktarim/kisi",
  "ice-aktarim-acilis_bakiye": "/ice-aktarim/acilis_bakiye",
  "ice-aktarim-arac": "/ice-aktarim/arac",
  // --- (P192 §3.1) gecikme faizi. PATCH kok kaynaga gider (`ayari`),
  // POST ise faizi ISLER.
  "gecikme-ayari": "/borclandirma/gecikme-ayari",
  "gecikme-faizi-isle": "/borclandirma/gecikme-faizi/isle",
  // --- (P192 §4) otomasyon. PATCH/DELETE alt kaynak yolundan
  // (`[kaynak]/[id]`) gecer; kok PATCH yalniz `hatirlatma-ayari` icin
  // anlamlidir (tesis basina TEK kayit).
  "aidat-planlari": "/aidat-planlari",
  "hatirlatma-ayari": "/hatirlatma-ayari",
  "duzenli-giderler": "/duzenli-giderler",
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
  // Ikisi de ZORUNLU: backend bunlarsiz 422 doner. Beyaz listede
  // olmasalardi vekil onlari duserdi ve her ek listesi hata verirdi.
  ekler: ["varlik_tipi", "varlik_id"],
  "otomasyon-gunlugu": ["tur"],
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
