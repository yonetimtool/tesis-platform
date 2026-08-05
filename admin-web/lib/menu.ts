// (P133.1) KENAR CUBUGU MENUSU — GRUPLAR, tek kaynak.
//
// NEDEN AYRI BIR MODUL: liste `AppShell.tsx` icinde yasiyordu ve orada
// yalnizca CIZIMLE birlikte test edilebiliyordu. Gruplama bir VERI
// kararidir (hangi sayfa hangi bolume ait, hangi bolum katli gelir) ve
// jsdom kurmadan olculebilmeli. Cizim testi ayrica duruyor — ikisi ayri
// hata sinifi: kume dogru olup kabugun onu okumamasi mumkundur.
//
// ROL KAPISI BURADA DEGIL: gorunurluk `yuzey.ts`teki `ROTA_ROLLERI`den
// gelir ve bu tur onu DEGISTIRMEDI. Buradaki tek is, gorunen kumeyi
// BOLUMLERE ayirmak.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

import { rotaRoldeGorunur, rotaYuzeyi, type Yuzey } from "./yuzey";

export type IconName =
  | "grid" | "building" | "clock" | "scan" | "route" | "check"
  | "box" | "home" | "edit" | "pin" | "money" | "chart"
  | "users" | "megaphone" | "chat" | "bell" | "hub" | "gear";

/** Bolum kimlikleri. Sira BURADAKI siradir (menude de bu sirayla cizilir). */
export type GrupId =
  | "guvenlik"
  | "tesis"
  | "finans"
  | "iletisim"
  | "yonetim"
  | "platform";

export interface MenuOgesi {
  href: string;
  anahtar: SozlukAnahtari;
  icon: IconName;
  grup: GrupId;
}

/**
 * KATLI GELEN BOLUMLER — tek bir "Daha fazla" satirinin ardinda.
 *
 * DURUSTCE: elimizde KULLANIM VERISI YOK (telemetri toplanmiyor). Bu
 * yuzden "en az kullanilan" bir OLCUM degil, bir URUN KARARIDIR:
 * `yonetim` kurulum ekranlaridir (kullanicilar, tanimlar, KVKK — haftada
 * bir acilir), `iletisim` ise duyuru/mesaj gibi ITME islerini tasir ve
 * gunluk devriye/aidat akisinin disindadir. Karar tek bir diziden okunur;
 * degistirmek bir satirlik istir.
 */
export const KATLI_GRUPLAR: readonly GrupId[] = ["iletisim", "yonetim"];

/** Bolum basligi anahtarlari. */
export const GRUP_ANAHTARI: Record<GrupId, SozlukAnahtari> = {
  guvenlik: "kabukGrupGuvenlik",
  tesis: "kabukGrupTesis",
  finans: "kabukGrupFinans",
  iletisim: "kabukGrupIletisim",
  yonetim: "kabukGrupYonetim",
  platform: "kabukGrupPlatform",
};

const GRUP_SIRASI: readonly GrupId[] = [
  "guvenlik",
  "tesis",
  "finans",
  "platform",
  "iletisim",
  "yonetim",
];

// Menu ogeleri METIN degil ANAHTAR tasir: etiket cizim aninda aktif dilde
// cozulur. Sira GRUP ICINDE anlamlidir (once gunluk bakilan, sonra kurulum).
const OGELER: readonly MenuOgesi[] = [
  // --- GUVENLIK: gunluk saha akisi --------------------------------------
  { href: "/dashboard", anahtar: "kabukCanliPanel", icon: "grid", grup: "guvenlik" },
  { href: "/olaylar", anahtar: "kabukOlaylar", icon: "bell", grup: "guvenlik" },
  { href: "/notifications", anahtar: "kabukBildirimler", icon: "bell", grup: "guvenlik" },
  { href: "/kameralar", anahtar: "kabukKameralar", icon: "scan", grup: "guvenlik" },
  { href: "/shifts", anahtar: "kabukVardiyalar", icon: "clock", grup: "guvenlik" },
  { href: "/checkpoints", anahtar: "kabukNfcNoktalari", icon: "scan", grup: "guvenlik" },
  { href: "/patrol-plans", anahtar: "kabukDevriyePlanlari", icon: "route", grup: "guvenlik" },
  { href: "/ziyaretciler", anahtar: "kabukZiyaretciler", icon: "users", grup: "guvenlik" },
  { href: "/kargolar", anahtar: "kabukKargolar", icon: "box", grup: "guvenlik" },
  { href: "/arac-gecisleri", anahtar: "kabukAracGecisleri", icon: "scan", grup: "guvenlik" },

  // --- TESIS: binanin kendisi -------------------------------------------
  { href: "/units", anahtar: "kabukDaireler", icon: "home", grup: "tesis" },
  { href: "/building-editor", anahtar: "kabukBinaDuzenleme", icon: "edit", grup: "tesis" },
  { href: "/tasks", anahtar: "kabukGorevler", icon: "check", grup: "tesis" },
  { href: "/gorevlerim", anahtar: "kabukGorevlerim", icon: "check", grup: "tesis" },
  { href: "/assets", anahtar: "kabukDemirbas", icon: "box", grup: "tesis" },
  { href: "/schematic", anahtar: "kabukSikayetHaritasi", icon: "pin", grup: "tesis" },
  { href: "/dis-hizmetler", anahtar: "kabukDisHizmetler", icon: "hub", grup: "tesis" },
  { href: "/etkinlikler", anahtar: "kabukEtkinlikler", icon: "clock", grup: "tesis" },
  { href: "/rezervasyonlarim", anahtar: "kabukRezervasyon", icon: "clock", grup: "tesis" },
  { href: "/kurallar", anahtar: "kabukKurallar", icon: "check", grup: "tesis" },

  // --- FINANS: para -----------------------------------------------------
  { href: "/dues", anahtar: "kabukAidat", icon: "money", grup: "finans" },
  { href: "/aidatim", anahtar: "kabukAidatim", icon: "money", grup: "finans" },
  { href: "/finans", anahtar: "kabukFinans", icon: "money", grup: "finans" },
  // (P111) Sayac okuma tanimlardan beslenir, ciktisi bir tahakkuktur.
  { href: "/sayac-okuma", anahtar: "kabukSayacOkuma", icon: "chart", grup: "finans" },
  { href: "/reports/dues", anahtar: "kabukRaporlar", icon: "chart", grup: "finans" },
  // (P40) 12 raporluk katalog; `/reports/dues` tek raporluk eski sayfadir
  // ve ikisi YAN YANA durur ki eski baglantilar kirilmasin.
  { href: "/raporlar", anahtar: "kabukRaporMotoru", icon: "chart", grup: "finans" },

  // --- PLATFORM: yalniz `panel.*` ---------------------------------------
  { href: "/tenants", anahtar: "kabukTesisler", icon: "building", grup: "platform" },
  { href: "/integrations", anahtar: "kabukEntegrasyonlar", icon: "hub", grup: "platform" },
  { href: "/settings", anahtar: "kabukAyarlar", icon: "gear", grup: "platform" },

  // --- ILETISIM: siteye seslenme + sakinden gelen -----------------------
  { href: "/announcements", anahtar: "kabukDuyurular", icon: "megaphone", grup: "iletisim" },
  { href: "/duyurular", anahtar: "kabukDuyurularim", icon: "megaphone", grup: "iletisim" },
  { href: "/mesajlar", anahtar: "kabukMesajlar", icon: "megaphone", grup: "iletisim" },
  { href: "/complaints", anahtar: "kabukTalepler", icon: "chat", grup: "iletisim" },
  { href: "/taleplerim", anahtar: "kabukTaleplerim", icon: "chat", grup: "iletisim" },
  { href: "/portal", anahtar: "kabukPortal", icon: "building", grup: "iletisim" },
  { href: "/yonetim-iletisim", anahtar: "kabukYonetimIletisim", icon: "chat", grup: "iletisim" },
  { href: "/support", anahtar: "kabukDestek", icon: "chat", grup: "iletisim" },

  // --- YONETIM: kurulum + hesap verebilirlik -----------------------------
  { href: "/users", anahtar: "kabukKullanicilar", icon: "users", grup: "yonetim" },
  { href: "/tanimlar", anahtar: "kabukTanimlar", icon: "box", grup: "yonetim" },
  { href: "/transparency", anahtar: "kabukSeffaflik", icon: "money", grup: "yonetim" },
  // (P40) Yonetisim denetim kaydinin YANINDA: ikisi de "ne karar alindi,
  // kim ne yapti" sorusunu yanitlar.
  { href: "/yonetisim", anahtar: "kabukYonetisim", icon: "building", grup: "yonetim" },
  { href: "/audit", anahtar: "kabukDenetimKaydi", icon: "scan", grup: "yonetim" },
  // (P41) Yetki matrisi denetimin yaninda.
  { href: "/yetki", anahtar: "kabukYetki", icon: "users", grup: "yonetim" },
  { href: "/kvkk", anahtar: "kabukKvkk", icon: "users", grup: "yonetim" },
];

/**
 * PROFIL GRUPTA DEGILDIR — alt bolumde, cikis dugmesinin yanindadir.
 *
 * Bir bolume koymak onu "yonetim isi" gibi gosterirdi; oysa kullanicinin
 * KENDI kaydidir ve her rolde ayni yerde durmasi beklenir. Gorunurlugu
 * yine `ROTA_ROLLERI`den gelir (bu tur degistirmedi).
 */
export const PROFIL_OGESI: MenuOgesi = {
  href: "/profil",
  anahtar: "kabukProfil",
  icon: "users",
  grup: "yonetim",
};

export interface MenuGrubu {
  id: GrupId;
  anahtar: SozlukAnahtari;
  ogeler: MenuOgesi[];
  /** Varsayilan olarak "Daha fazla"nin ardinda mi? */
  katli: boolean;
}

/**
 * Yuzey + role gorunen menuyu BOLUMLENMIS dondurur.
 *
 * BOS BOLUM CIZILMEZ: denetci dort sayfa goruyor; bes baslik altinda dort
 * satir gostermek, menuyu kisaltmak icin yapilan isi tersine cevirirdi.
 */
export function menuGruplari(yuzey: Yuzey, rol: string | null): MenuGrubu[] {
  const gorunen = OGELER.filter(
    (o) => rotaYuzeyi(o.href) === yuzey && rotaRoldeGorunur(o.href, rol),
  );
  return GRUP_SIRASI.map((id) => ({
    id,
    anahtar: GRUP_ANAHTARI[id],
    ogeler: gorunen.filter((o) => o.grup === id),
    katli: KATLI_GRUPLAR.includes(id),
  })).filter((g) => g.ogeler.length > 0);
}

/** Profil satiri bu rolde gorunuyor mu? */
export function profilGorunur(yuzey: Yuzey, rol: string | null): boolean {
  return (
    rotaYuzeyi(PROFIL_OGESI.href) === yuzey &&
    rotaRoldeGorunur(PROFIL_OGESI.href, rol)
  );
}

/**
 * Bir rotanin ait oldugu bolum — acilista HANGI bolumun acik gelecegini
 * bulmak icin.
 *
 * Bilinmeyen rota `null` doner ve o durumda ILK bolum acilir (bkz. kabuk):
 * "hicbiri acik degil" hâli, menuyu bos bir baslik listesine cevirirdi.
 */
export function rotaninGrubu(pathname: string): GrupId | null {
  const tam = OGELER.find((o) => o.href === pathname);
  if (tam) return tam.grup;
  // `/reports/patrols` gibi alt rotalar: en uzun onek eslesmesi.
  const onek = OGELER.filter((o) => pathname.startsWith(`${o.href}/`)).sort(
    (a, b) => b.href.length - a.href.length,
  )[0];
  return onek?.grup ?? null;
}

/** Yalniz testler icin: ham liste (her ogenin bir gruba dustugu olculur). */
export const _OGELER = OGELER;
