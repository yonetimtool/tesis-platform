"use client";

/**
 * (P161 §4) TEMA — TEK KAYNAK.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA
 * =========================================================================
 * Tema uc yerden degisiyordu: kullanicinin anahtara basmasi, isletim
 * sistemi tercihinin degismesi, ve sayfa acilisindaki satir-ici script.
 * Uygulama mantigi (hangi mod hangi sinifi verir, gecis nasil yumusar)
 * `ThemeToggle` bileseninin icindeydi — yani sahne, harita ya da baska
 * bir yerden tema degistirmek isteyen kod ayni kurallari TEKRAR yazmak
 * zorunda kalacakti.
 *
 * =========================================================================
 * GECIS SINIFI NEDEN GECICI
 * =========================================================================
 * `.yz-tema-gecisi` 200 ms boyunca butun renk ozelliklerine gecis verir.
 * KALICI olsaydi her hover, her odak, her durum degisimi de 200 ms
 * surunurdu — tepkisiz bir arayuz. Sinif eklenir, gecis biter, kaldirilir.
 */

export type TemaModu = "system" | "light" | "dark";

export const TEMA_ANAHTARI = "theme";
const KOYU_SINIF = "dark";
const GECIS_SINIFI = "yz-tema-gecisi";
/** CSS'teki 200 ms + kucuk bir pay (gecis bitmeden sinif kalkmasin). */
const GECIS_SURESI = 220;

let gecisZamanlayici: ReturnType<typeof setTimeout> | null = null;

export function sistemKoyuMu(): boolean {
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false;
}

export function koyuMu(mod: TemaModu): boolean {
  return mod === "dark" || (mod === "system" && sistemKoyuMu());
}

/**
 * Modu uygular. `yumusak` verilirse 200 ms'lik renk gecisi acilir.
 *
 * ILK YUKLEMEDE YUMUSAK OLMAZ: sayfa acilirken tema zaten dogru; gecis
 * acmak, acilisi bir renk animasyonuyla baslatmak olurdu.
 */
export function temayiUygula(mod: TemaModu, yumusak = false): void {
  const kok = document.documentElement;
  if (yumusak) {
    kok.classList.add(GECIS_SINIFI);
    if (gecisZamanlayici) clearTimeout(gecisZamanlayici);
    gecisZamanlayici = setTimeout(() => {
      kok.classList.remove(GECIS_SINIFI);
      gecisZamanlayici = null;
    }, GECIS_SURESI);
  }
  kok.classList.toggle(KOYU_SINIF, koyuMu(mod));
}

/**
 * Kayitli tercih. OKUMA KORUMALI: gizli sekmede ya da depolama
 * engelliyken `localStorage` ERISIMI FIRLATIR ve bu, tema anahtarini
 * degil TUM KABUGU cizilemez hale getiriyordu (P160'ta olculdu).
 */
export function kayitliMod(): TemaModu | null {
  try {
    const ham = localStorage.getItem(TEMA_ANAHTARI);
    return ham === "light" || ham === "dark" || ham === "system" ? ham : null;
  } catch {
    return null;
  }
}

export function moduKaydet(mod: TemaModu): void {
  try {
    localStorage.setItem(TEMA_ANAHTARI, mod);
  } catch {
    // Yazilamazsa tercih bu oturumda gecerli olur, kalici olmaz.
  }
}
