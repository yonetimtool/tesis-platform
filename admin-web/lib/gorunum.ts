/**
 * (P243 §4) GORUNUM MODU — STANDART / BUYUK.
 *
 * =========================================================================
 * NEDEN VAR
 * =========================================================================
 * Kullanicilarimiz yalniz gencler degil; 60 yas ustu yoneticiler de sol
 * menuyu okuyabilmeli. Mobilde bu ayar P230'da yapildi ("Gorunum modu:
 * Standart / Buyuk"); web'de yoktu.
 *
 * =========================================================================
 * MOBILDEKI AYARLA AYNI KAVRAM
 * =========================================================================
 * Ayni ad, ayni iki secenek, ayni davranis. Kullanici iki yuzeyde iki
 * farkli sey ogrenmesin (istegin acik sarti).
 *
 * =========================================================================
 * UC KATMAN — VE HER BIRININ NEDENI
 * =========================================================================
 *  1. HESAP (`app_user.ui_gorunum`, goc 0147): baska bir tarayicida da
 *     ayni gorunum gelsin. Tema ile ayni gerekce (goc 0076).
 *  2. CEREZ: SSR ilk karede sinifi basabilsin. Cerez olmasaydi sayfa
 *     once KUCUK cizilir, sonra buyurdu — tam da bu ayara ihtiyac duyan
 *     kullaniciyi bir kare boyunca okuyamaz birakirdi.
 *  3. `localStorage` YOK ve bilincli: tema orada geriye donuk uyum icin
 *     duruyor; burada boyle bir miras yok ve ucuncu bir kaynak, hangisi
 *     dogru sorusunu ucuncu kez sordururdu.
 */
export type GorunumModu = "standart" | "buyuk";

export const GORUNUM_CEREZI = "gorunum";
const BUYUK_SINIF = "yz-buyuk";

/** Cerez alan-genelinde yazilir: app.* ve panel.* AYNI tercihi gorur. */
export function gorunumCerezYaz(mod: GorunumModu): void {
  const alan =
    typeof location !== "undefined" && location.hostname.includes(".")
      ? `; domain=.${location.hostname.split(".").slice(-2).join(".")}`
      : "";
  document.cookie =
    `${GORUNUM_CEREZI}=${mod}; path=/; max-age=31536000; samesite=lax${alan}`;
}

export function gorunumuUygula(mod: GorunumModu): void {
  document.documentElement.classList.toggle(BUYUK_SINIF, mod === "buyuk");
}

export function gorunumCoz(ham: string | null | undefined): GorunumModu {
  return ham === "buyuk" ? "buyuk" : "standart";
}
