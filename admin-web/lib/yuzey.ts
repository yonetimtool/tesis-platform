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
 * `tesis_gorevlisi` HALA DISARIDA: "gorevlerim" ve daire erisim sayfalari
 * yok (bkz. `docs/app-web-bosluk-tablosu.md`); P126.6'da eklenecek.
 */
const TESIS_ROLLERI = new Set(["yonetici", "admin", "resident", "security"]);

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
    !!rol && ["tesis_gorevlisi", "guvenlik_amiri"].includes(rol)
  );
}
