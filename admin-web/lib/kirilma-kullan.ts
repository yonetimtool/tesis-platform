"use client";

// (P169 §1) `useBant` / `useMedya` — TEK DINLEYICI, PAYLASIMLI.
//
// =========================================================================
// NEDEN `useSyncExternalStore`, NEDEN `useState` + `useEffect` DEGIL
// =========================================================================
// Brief: "her bilesen kendi dinleyicisini kurmasin."
//
// Klasik `useState` + `useEffect(resize)` deseni her cagiran icin AYRI bir
// dinleyici kurar. Yirmi bilesen kullanirsa yirmi dinleyici olur ve her
// yeniden boyutlandirmada yirmi kez state guncellenir — telefonu dondurmek
// ya da klavye acmak bunu tetikler.
//
// `useSyncExternalStore` sorgu BASINA tek bir `matchMedia` dinleyicisi
// kurar ve tum aboneler onu paylasir. Ayrica SSR guvenlidir: sunucu anlik
// goruntusu ayri verilir.
//
// SUNUCUDA HANGI DEGER DONER: `false` (yani "genis ekran / ince isaretci").
// Sebep: sunucu ekran genisligini BILEMEZ ve tahmin etmek, ilk cizimle
// montaj sonrasi cizimin farkli olmasi (hydration uyusmazligi) demektir.
// `false` donmek, masaustu duzenini cizip montajda daralt demektir —
// tersi (mobili cizip genislet) masaustu kullanicisina bir kare boyunca
// telefon duzeni gosterirdi.

import { useSyncExternalStore } from "react";

import { BANTLAR, KABA_ISARETCI, bantSorgusu, type Bant } from "./kirilma-noktasi";

interface Kayit {
  liste: MediaQueryList;
  aboneler: Set<() => void>;
  dinleyici: (() => void) | null;
}

/** Sorgu -> tek kayit. MODUL DUZEYINDE: butun bilesenler paylasir. */
const kayitlar = new Map<string, Kayit>();

function kayitAl(sorgu: string): Kayit {
  let k = kayitlar.get(sorgu);
  if (!k) {
    k = { liste: window.matchMedia(sorgu), aboneler: new Set(), dinleyici: null };
    kayitlar.set(sorgu, k);
  }
  return k;
}

function aboneOl(sorgu: string) {
  return (bildir: () => void) => {
    // TARAYICI YOKSA (SSR) hicbir sey yapma — `getServerSnapshot` devrede.
    if (typeof window === "undefined") return () => {};
    const k = kayitAl(sorgu);
    k.aboneler.add(bildir);
    if (!k.dinleyici) {
      k.dinleyici = () => k!.aboneler.forEach((f) => f());
      k.liste.addEventListener("change", k.dinleyici);
    }
    return () => {
      k.aboneler.delete(bildir);
      // SON ABONE GIDINCE DINLEYICI DE GIDER: aksi halde sayfa
      // gezindikce olu dinleyiciler birikirdi.
      if (k.aboneler.size === 0 && k.dinleyici) {
        k.liste.removeEventListener("change", k.dinleyici);
        k.dinleyici = null;
      }
    };
  };
}

/** Bir medya sorgusu esliyor mu. Sunucuda DAIMA `false`. */
export function useMedya(sorgu: string): boolean {
  return useSyncExternalStore(
    aboneOl(sorgu),
    () => (typeof window === "undefined" ? false : kayitAl(sorgu).liste.matches),
    () => false,
  );
}

/**
 * Suanki BANT. Sunucuda ve ilk cizimde `xl` doner (bkz. dosya basi notu).
 *
 * DAVRANIS DEGISTIRMEK ICIN kullanilir (orn. tablo modu). SALT GORSEL
 * degisiklikler icin KULLANILMAZ — onlar CSS'te `sm:`/`lg:` onekleriyle
 * yapilir ve JS'e hic ugramaz.
 */
export function useBant(): Bant {
  // Her bant icin ayri sorgu; en genisten baslayip ilk eslesen alinir.
  // Kanca sayisi SABIT (dort) — kosullu cagri yok.
  const xl = useMedya(bantSorgusu("xl"));
  const lg = useMedya(bantSorgusu("lg"));
  const md = useMedya(bantSorgusu("md"));
  const sm = useMedya(bantSorgusu("sm"));
  const eslesme: Record<Bant, boolean> = { xl, lg, md, sm };
  return BANTLAR.find((b) => eslesme[b]) ?? "xl";
}

/** Bu bant ve USTU mu (orn. `useBantEnAz("lg")`). */
export function useBantEnAz(bant: Bant): boolean {
  const su = useBant();
  return BANTLAR.indexOf(su) <= BANTLAR.indexOf(bant);
}

/**
 * PARMAKLA MI KULLANILIYOR — genislikten AYRI soru.
 *
 * Dokunma hedefi buyutme karari buna baglanir, genislige DEGIL: fareyle
 * calisan dar bir pencerede tablolari sismek gereksizdir.
 */
export function useDokunmatik(): boolean {
  return useMedya(KABA_ISARETCI);
}
