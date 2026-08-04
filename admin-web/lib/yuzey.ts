// (P125) YUZEY AYRIMI — hangi rota PLATFORM'a, hangisi TESIS'e ait?
//
// Kerem'in urun karari: `panel.yönetiyor.com` YALNIZ platform sahibinin
// yuzeyidir (tesis yonetimi, platform ayarlari, tesisler-arasi gorunumler,
// islem gecmisi). Tek bir sitenin islemleri — aidat tahsilati, sayac
// okuma, vardiya — oraya GIRMEZ; onlar `app.yönetiyor.com`a (P126) gider.
//
// NEDEN AYRI BIR MODUL: siniflandirma iki yerde birden gerekiyor — menuyu
// suzmek ve TESTLE kanitlamak. Iki kopya tutulsaydi biri guncellenir,
// oteki sessizce eskir ve "panel platform-only" iddiasi dogrulanamaz hale
// gelirdi. Tek kaynak burasi; `AppShell` de testler de bunu okur.
//
// SINIFLANDIRMANIN GEREKCESI belgede: `docs/platform-tesis-ayrimi.md`.
// Orada 317 uçluk rol matrisinden okunarak yapildi, tahminle degil.

/** Bir rotanin ait oldugu yuzey. */
export type Yuzey = "platform" | "tesis";

/**
 * PLATFORM rotalari — `panel.*`ta kalir.
 *
 * Hepsi TESISLER-ARASI ya da platformun kendi isidir. `users` burada
 * DEGILDIR: o bir tesisin personel/sakin listesidir. Platformun kullanici
 * isi `tenants/[id]` icindeki "yonetici ata / kimlik sifirla" akisidir ve
 * o zaten `/tenants` altindadir.
 */
export const PLATFORM_ROTALARI = [
  "/tenants",
  "/audit",
  "/support",
  "/integrations",
  "/yetki",
  "/settings",
] as const;

/**
 * TESIS rotalari — P126'da `app.*`a tasinir.
 *
 * Bugun kod tabaninda duruyorlar ve `admin` bir yer imiyle hâlâ acabilir
 * (yetki GERI ALINMADI — bkz. belgedeki duzeltilmis karar). Degisen sey
 * PANEL MENUSUNDE GORUNMEMELERI: panelin isi platformu yonetmek.
 */
export const TESIS_ROTALARI = [
  "/dashboard",
  "/shifts",
  "/checkpoints",
  "/patrol-plans",
  "/tasks",
  "/assets",
  "/units",
  "/building-editor",
  "/schematic",
  "/tanimlar",
  "/sayac-okuma",
  "/dues",
  "/finans",
  "/reports/dues",
  "/reports/patrols",
  "/reports/tasks",
  "/raporlar",
  "/transparency",
  "/users",
  "/announcements",
  "/mesajlar",
  "/portal",
  "/complaints",
  "/notifications",
  "/yonetisim",
  // (P126.3) Tesis rollerinin KENDI kayitlari (sakin calisma alani).
  "/profil",
  "/aidatim",
  "/taleplerim",
  "/duyurular",
  "/kurallar",
  "/etkinlikler",
  "/rezervasyonlarim",
  "/kvkk",
  // (P126.4) Guvenligin kapi ekranlari.
  "/ziyaretciler",
  "/kargolar",
  "/olaylar",
  "/arac-gecisleri",
  // (P126.6) Saha rolunun kendi gorevleri.
  "/gorevlerim",
  // (P126.5) Yoneticinin eksik ekranlari.
  "/kameralar",
  "/dis-hizmetler",
  "/yonetim-iletisim",
] as const;

/**
 * Bir rotanin yuzeyi. Bilinmeyen rota `null` doner — "varsayilan olarak
 * platform" demek, yeni bir tesis sayfasinin panele SESSIZCE sizmasi
 * olurdu. Test bilinmeyen rota birakmayi reddediyor.
 */
export function rotaYuzeyi(href: string): Yuzey | null {
  if ((PLATFORM_ROTALARI as readonly string[]).includes(href)) return "platform";
  if ((TESIS_ROTALARI as readonly string[]).includes(href)) return "tesis";
  return null;
}

/**
 * Konaktan yuzey. `app.` ile baslayan her konak TESIS yuzeyidir; digerleri
 * (panel.*, yerel gelistirme) PLATFORM.
 *
 * NEDEN KONAKTAN: ayni Next.js uygulamasi iki alan adindan sunuluyor
 * (bkz. infra/Caddyfile). Rolden turetmek yanlis olurdu — `admin` her iki
 * yuzeye de girebilir ve hangisinde oldugunu ancak adres soyler.
 */
export function konakYuzeyi(host: string | null | undefined): Yuzey {
  const h = (host ?? "").toLowerCase().split(":")[0];
  return h.startsWith("app.") ? "tesis" : "platform";
}

/**
 * Yuzeyin KOK rotasi (logo hedefi).
 *
 * Modulde durur, cizim katmaninda bir ucluda DEGIL: `sabit-metin` taramasi
 * ucludaki satir-ici dizgeleri hakli olarak "cevrilmemis metin" adayi
 * sayiyor. Ayrica hedef, yuzey tanimiyla AYNI yerde durmali — panelde
 * tesis panosu yoktur, o bilgi buraya aittir.
 */
export function kokRota(yuzey: Yuzey): string {
  return yuzey === "platform" ? "/tenants" : "/dashboard";
}

/**
 * Yuzeyin kok rotasi, ROLE GORE (P126.7).
 *
 * `kokRota` tesis yuzeyinde `/dashboard` verir — ama panoyu YALNIZ yonetim
 * gorur. Sakini oraya yollamak, giris yapar yapmaz goremeyecegi bir sayfaya
 * atmak demekti (ve middleware onu tekrar yonlendirirdi: dongu).
 *
 * SIRA ONEMLI ve ROLLERIN ISINE GORE kuruldu: guvenligin gunu KAPIDA
 * gecer (ziyaretci/kargo), gorev ikincil isidir — bu yuzden `/ziyaretciler`
 * `/gorevlerim`den ONCE gelir. Saha gorevlisi ziyaretci ekranini goremedigi
 * icin dogal olarak `/gorevlerim`e duser. Hicbirini goremeyen rol icin
 * `/profil` her tesis rolunde vardir.
 */
const KOK_ADAYLARI = [
  "/dashboard",
  "/ziyaretciler",
  "/gorevlerim",
  "/aidatim",
  "/profil",
];

export function kokRotaRol(yuzey: Yuzey, rol: string | null): string {
  if (yuzey === "platform") return kokRota("platform");
  return KOK_ADAYLARI.find((r) => rotaRoldeGorunur(r, rol)) ?? kokRota("tesis");
}

// --------------------------------------------------------------------------- #
// ROL x YUZEY KAPISI (P126.1)
//
// `panel.*` platform sahibinindir; `app.*` tesis rollerinindir. Bu kapi bir
// UX kapisidir, GUVENLIK SINIRI DEGIL: gercek yetki her istekte backend
// RBAC'ta zorlanir (contracts/auth.md §4, 317 ucluk rol matrisi). Ama yanlis
// yuzeye giren kullaniciya isini yapamayacagi bir kabuk gostermek, "sistem
// bozuk" izlenimi uretir — kapi bunu onler.

/** Platform yuzeyine girebilen roller. */
const PLATFORM_ROLLERI = new Set(["admin"]);

/**
 * Tesis yuzeyine (`app.*`) girebilen roller.
 *
 * `resident` (P126.3 sonunda) EKLENDI: sakinin gunluk isini web'den
 * yapabilecegi set TAMAMLANDI — Aidatim, Taleplerim, Duyurular, Kurallar,
 * Etkinlikler, Rezervasyonlarim, KVKK tercihleri, Profil. Bir rolu ancak
 * KENDI sayfalari hazir oldugunda iceri almak, girer girmez her yerde 403
 * goren bir ekran vermemek icindi.
 *
 * `security` (P126.4 sonunda) EKLENDI: kapi seti tamamlandi —
 * Ziyaretciler, Kargolar, Olaylar, Arac gecisleri (+ Profil).
 *
 * `tesis_gorevlisi` (P126.6 sonunda) EKLENDI: "Gorevlerim" + Profil.
 * `unit_access` bu role ATANMAMISTI — olculdu: o akisin rolleri
 * admin/yonetici (talep) ve resident (karar); bosluk tablosundaki atama
 * yanlisti ve duzeltildi.
 *
 * `guvenlik_amiri` (P35) HENUZ DISARIDA: rol backend'de var ama kendi
 * ekran seti tanimlanmadi.
 */
const TESIS_ROLLERI = new Set([
  "yonetici",
  "admin",
  "resident",
  "security",
  "tesis_gorevlisi",
]);

/**
 * ROL x ROTA — `app.*`ta HANGI ROLE HANGI SAYFA GOSTERILIR.
 *
 * NEDEN GEREKLI: P126.1-.6 boyunca menu YALNIZ YUZEYE gore suzuluyordu.
 * Sonuc: `app.*`a giren bir SAKIN, vardiya cizelgesinden tahakkuk
 * olusturmaya kadar 39 baglantiyi goruyordu. Hicbirini acamiyordu — sunucu
 * 403 donuyor — ama "goruyorum, tiklayinca calismiyor" tam olarak
 * `yuzey.ts`in bastan beri onlemeye calistigi "sistem bozuk" izlenimidir.
 *
 * BU BIR YETKILENDIRME DEGILDIR (gorunurluk yetkilendirme olmaz): gercek
 * kapi sunucudadir ve olculmustur — `backend/tests/yetki/rol-matrisi.txt`,
 * koddan uretilen 318 satirlik kilit.
 *
 * KUME NASIL SECILDI — IKI KATMAN:
 *   1. ERISIM (olculur): rol o sayfanin BIRINCIL ucundan 403 aliyorsa
 *      sayfa menude OLAMAZ. `tests/rol-menusu.test.ts` her satiri matris
 *      kilidiyle karsilastirir; bir gun bir uc daraltilirsa test duser.
 *   2. NIYET (urun karari): erisim yeterli sart DEGIL. `GET /cameras` her
 *      role acik ama Kameralar sayfasi bir YONETIM ekranidir; sakine
 *      kamera gorunumu ayri bir urun kararidir ve bu turda ALINMADI.
 *
 * Yani asagidaki kume her zaman erisim kumesinin ALT KUMESIDIR.
 */
export const ROTA_ROLLERI: Record<string, readonly string[]> = {
  // --- YONETIM EKRANLARI: yonetici + admin -------------------------------
  "/dashboard": ["admin", "yonetici"],
  "/shifts": ["admin", "yonetici"],
  "/checkpoints": ["admin", "yonetici"],
  "/patrol-plans": ["admin", "yonetici"],
  "/tasks": ["admin", "yonetici"],
  "/assets": ["admin", "yonetici"],
  "/units": ["admin", "yonetici"],
  "/building-editor": ["admin", "yonetici"],
  "/schematic": ["admin", "yonetici"],
  "/tanimlar": ["admin", "yonetici"],
  "/sayac-okuma": ["admin", "yonetici"],
  "/dues": ["admin", "yonetici"],
  "/finans": ["admin", "yonetici"],
  "/reports/dues": ["admin", "yonetici"],
  "/reports/patrols": ["admin", "yonetici"],
  "/reports/tasks": ["admin", "yonetici"],
  "/raporlar": ["admin", "yonetici"],
  "/transparency": ["admin", "yonetici"],
  "/users": ["admin", "yonetici"],
  "/announcements": ["admin", "yonetici"],
  "/mesajlar": ["admin", "yonetici"],
  "/portal": ["admin", "yonetici"],
  "/complaints": ["admin", "yonetici"],
  "/notifications": ["admin", "yonetici"],
  "/yonetisim": ["admin", "yonetici"],
  "/kameralar": ["admin", "yonetici"],
  // Olaylar YONETIMDE DE var: guvenlik bildirir, yonetim okur.
  "/olaylar": ["admin", "yonetici", "security"],

  // --- SAKIN -------------------------------------------------------------
  "/aidatim": ["resident"],
  "/taleplerim": ["resident"],
  "/kurallar": ["resident"],
  "/etkinlikler": ["resident"],
  "/rezervasyonlarim": ["resident"],

  // --- GUVENLIK ----------------------------------------------------------
  "/ziyaretciler": ["security"],
  "/kargolar": ["security"],
  // `yonetici` BU SAYFAYI GOREMEZ ve bu bir tercih degil OLCUM:
  // `GET /vehicle-passes` yoneticiye 403 doner (matris kilidi). Menuye
  // koymak, tiklayinca bos ekran demekti.
  "/arac-gecisleri": ["admin", "security"],

  // --- SAHA (gorev alan roller) -----------------------------------------
  "/gorevlerim": ["security", "tesis_gorevlisi"],

  // --- HERKESIN / PAYLASILAN --------------------------------------------
  "/profil": ["admin", "yonetici", "resident", "security", "tesis_gorevlisi"],
  "/kvkk": ["admin", "yonetici", "resident", "security", "tesis_gorevlisi"],
  // Duyurular sakinin OKUMA gorunumu; personel de site duyurusunu gorur.
  "/duyurular": ["resident", "security", "tesis_gorevlisi"],
  // Guvenilir esnaf: sunucu "herkes gorur/arayabilir" diyor (routers/
  // external_services.py). Yonetici icin ayni sayfa YAZMA formunu da acar.
  "/dis-hizmetler": ["admin", "yonetici", "resident", "security", "tesis_gorevlisi"],
  // Yonetime ulasma karti YONETICIYE gosterilmez: kendi numarasini kendine
  // gostermek bir is akisi degildir.
  "/yonetim-iletisim": ["resident", "security", "tesis_gorevlisi"],
};

/**
 * [href] rotasi [rol] icin menude gorunur mu?
 *
 * PLATFORM rotalarinda rol ayrimi YOKTUR: o yuzeye zaten yalniz `admin`
 * girebiliyor (bkz. PLATFORM_ROLLERI) ve hepsi onun isidir.
 *
 * ROL BILINMIYORSA (`null`) HICBIR SEY gorunmez. "Bilmiyorsak gosterelim"
 * demek, sakine yonetim menusunu bir an icin de olsa cizmek olurdu.
 */
export function rotaRoldeGorunur(href: string, rol: string | null): boolean {
  const yuzey = rotaYuzeyi(href);
  if (yuzey === null) return false;
  if (yuzey === "platform") return rolYuzeyeGirebilir(rol, "platform");
  if (!rol) return false;
  return (ROTA_ROLLERI[href] ?? []).includes(rol);
}

/** [rol] bu [yuzey]e girebilir mi? */
export function rolYuzeyeGirebilir(rol: string | null, yuzey: Yuzey): boolean {
  if (!rol) return false;
  return yuzey === "platform"
    ? PLATFORM_ROLLERI.has(rol)
    : TESIS_ROLLERI.has(rol);
}

/** Henuz `app.*`a alinmamis tesis rolleri (giriste "yakinda" mesaji icin). */
export function tesisYuzeyiBekleyenRol(rol: string | null): boolean {
  return (
    !!rol && ["guvenlik_amiri"].includes(rol)
  );
}
