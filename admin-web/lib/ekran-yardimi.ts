// (P243 §6e) BAGLAM ICI YARDIM — rota -> "bu ekran ne ise yarar".
//
// NEDEN `lib`DE: `kurulum-adimlari.ts` ile ayni gerekce — Next.js sayfa
// dosyalari yalniz bilinen disa aktarimlara izin verir, ve bu bir URUN
// BILGISI kaydidir, cizim detayi degil.
//
// NEDEN HER ROTAYA YAZILMADI: bir "?" dugmesinin acip "bu ekran icin
// aciklama yazilmadi" demesi, dugmenin hic olmamasindan KOTUDUR —
// kullanici bir kez tiklar, bos cikar, bir daha tiklamaz. Bu yuzden
// kayit YENI YONETICININ ILK HAFTADA DOKUNDUGU ekranlari kapsar ve
// dugme yalniz kaydi olan ekranda cizilir. Liste zamanla buyur.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * Yol -> aciklama anahtari. Anahtar EN UZUN ONEKE gore secilir:
 * `/finans/butce` kaydi yoksa `/finans` kaydi kullanilir — alt
 * sayfalarin her biri icin ayri metin yazmak, ayni seyi farkli
 * kelimelerle bes kez soylemek olurdu.
 */
export const EKRAN_YARDIMI: Record<string, SozlukAnahtari> = {
  "/dashboard": "yardimDashboard",
  "/kurulum": "yardimKurulum",
  "/users": "yardimUsers",
  // (E2E 2026-09) Sakinler ekrani hesap ACMAZ; Kullanicilar metni
  // ("kisiyi eklediginizde davet gider") burada yanlisti.
  "/residents": "yardimResidents",
  "/building-editor": "yardimBuildingEditor",
  "/tasks": "yardimTasks",
  "/dues": "yardimDues",
  "/finans": "yardimFinans",
  "/vardiya-plani": "yardimVardiyaPlani",
  "/shifts": "yardimVardiyaPlani",
  "/ice-aktarim": "yardimIceAktarim",
  "/announcements": "yardimAnnouncements",
  "/kameralar": "yardimKameralar",
  "/kamera-kayitlari": "yardimKameralar",
  "/panik": "yardimPanik",
  "/bakim": "yardimBakim",
  "/tanimlar": "yardimTanimlar",
  "/raporlar": "yardimRaporlar",
  "/reports": "yardimRaporlar",
  "/tesis-ayarlari": "yardimAyarlar",
  "/settings": "yardimAyarlar",
  // (E2E 2026-09) KURULUM-11: yeni yoneticinin ilk haftada dokundugu ama
  // "?" dugmesi OLMAYAN ekranlar. Her metin sayfanin koduna bakilarak
  // yazildi (ne yapar / ne YAPMAZ / nereye gidilir).
  "/units": "yardimUnits",
  "/assets": "yardimAssets",
  "/checkpoints": "yardimCheckpoints",
  "/patrol-plans": "yardimPatrolPlans",
  "/anketler": "yardimAnketler",
  "/etkinlik-yonetimi": "yardimEtkinlik",
  "/complaints": "yardimComplaints",
  "/rezervasyon-yonetimi": "yardimRezervasyon",
  "/arac-gecisleri": "yardimAracGecisleri",
  "/akilli-ev": "yardimAkilliEv",
  "/sayac-okuma": "yardimSayacOkuma",
  "/transparency": "yardimTransparency",
  // Finans alt sayfalari: `/finans` ortak metni ("tek defter") butce ve
  // borclular ekranini ANLATMIYORDU. Bu dort ekran kendi isini soyler;
  // kalanlar (virman, iade, acilis...) `/finans` metnine duser.
  "/finans/borclular": "yardimBorclular",
  "/finans/butce": "yardimButce",
  "/finans/giderler": "yardimGiderler",
  "/finans/tahsilatlar": "yardimTahsilatlar",
  "/finans/gelirler": "yardimGelirler",
};

/** Yol icin aciklama anahtari — en uzun onek kazanir; yoksa `null`. */
export function ekranYardimi(yol: string | null): SozlukAnahtari | null {
  if (!yol) return null;
  let kazanan: string | null = null;
  for (const onek of Object.keys(EKRAN_YARDIMI)) {
    if (yol === onek || yol.startsWith(`${onek}/`)) {
      if (kazanan === null || onek.length > kazanan.length) kazanan = onek;
    }
  }
  return kazanan === null ? null : EKRAN_YARDIMI[kazanan];
}
