"use client";

// (P244 §3) ODAK TUZAGI — PAYLASILAN KANCA.
//
// ===========================================================================
// NEDEN CIKARILDI
// ===========================================================================
// `components/ui/modal.tsx` icinde yaziliydi. Asama 3'te DETAY CEKMECESI
// eklendi ve o da tam olarak ayni seye ihtiyac duyuyor: ESC ile kapanma,
// acilista ice odak, kapanista ACAN OGEYE geri donus, Tab'in katmanin
// icinde donmesi.
//
// Ikinci bir kopya yazmak, erisilebilirligin en kolay unutulan parcasini
// iki yerde tutmak olurdu — ve P161'de olculen su ders tam burada
// kaybolurdu:
//
//   GORUNURLUK SUZGECI `offsetParent !== null` OLAMAZ. jsdom'da bu HER
//   ZAMAN null doner, yani tuzak TESTTE SESSIZCE DEVRE DISI kalir
//   (`ogeler.length === 0` -> erken cikis) ve hic olculemez. Yerine
//   gercekten gizlenmis ogeleri eleyen bir kural kullanilir: `hidden`,
//   `aria-hidden` ya da `display:none`. Ayni sonucu verir, tarayicinin
//   duzen motoruna bagli DEGILDIR.

import { useEffect, type RefObject } from "react";

export const ODAKLANABILIR =
  'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';

/** Katman icindeki GERCEKTEN odaklanabilir ogeler (gizliler elenir). */
export function odaklanabilirler(kap: HTMLElement): HTMLElement[] {
  return [...kap.querySelectorAll<HTMLElement>(ODAKLANABILIR)].filter(
    (o) =>
      !o.closest("[hidden]") &&
      !o.closest('[aria-hidden="true"]') &&
      getComputedStyle(o).display !== "none",
  );
}

/**
 * Acilista ice odaklan, kapanista ACAN OGEYE don.
 *
 * `ilkRef` verilirse odak once ORADA aranir — modalde olculen kusur
 * buydu (P161): kutunun tamaminda arayinca basliktaki KAPAT dugmesi
 * kazaniyor ve klavye kullanicisi yazmaya baslamak icin once Tab'lamak
 * zorunda kaliyordu.
 */
export function useOdakDonusu(
  acik: boolean,
  kapRef: RefObject<HTMLElement | null>,
  ilkRef?: RefObject<HTMLElement | null>,
): void {
  useEffect(() => {
    if (!acik) return;
    const acan = document.activeElement as HTMLElement | null;
    const ilk =
      ilkRef?.current?.querySelector<HTMLElement>(ODAKLANABILIR) ??
      kapRef.current?.querySelector<HTMLElement>(ODAKLANABILIR);
    (ilk ?? kapRef.current)?.focus();
    return () => {
      acan?.focus?.();
    };
  }, [acik, kapRef, ilkRef]);
}

/** ESC kapatir; Tab/Shift+Tab katmanin ICINDE doner. */
export function useOdakTuzagi(
  acik: boolean,
  kapRef: RefObject<HTMLElement | null>,
  onKapat: () => void,
): void {
  useEffect(() => {
    if (!acik) return;
    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") {
        // `stopPropagation`: ic ice katmanlarda yalnizca EN USTTEKI
        // kapanmali, alttaki de birlikte kapanmamali.
        e.stopPropagation();
        onKapat();
        return;
      }
      if (e.key !== "Tab") return;
      const kap = kapRef.current;
      if (!kap) return;
      const ogeler = odaklanabilirler(kap);
      if (ogeler.length === 0) return;
      const ilk = ogeler[0];
      const son = ogeler[ogeler.length - 1];
      if (e.shiftKey && document.activeElement === ilk) {
        e.preventDefault();
        son.focus();
      } else if (!e.shiftKey && document.activeElement === son) {
        e.preventDefault();
        ilk.focus();
      }
    }
    document.addEventListener("keydown", tus, true);
    return () => document.removeEventListener("keydown", tus, true);
  }, [acik, kapRef, onKapat]);
}
