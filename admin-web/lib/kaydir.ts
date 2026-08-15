"use client";

/**
 * (P162 §7.1) ACILAN ALANA YUMUSAK KAYDIRMA — TEK YARDIMCI.
 *
 * =========================================================================
 * OLCULEN KUSUR
 * =========================================================================
 * "Detay" ya da "Kayit getir" gibi dugmelere basildiginda sayfanin
 * ALTINDA bir alan aciliyor ama gorunum yerinde kaliyordu: kullanici
 * tikliyor, ekranda hicbir sey degismiyor gibi gorunuyor, sonra elle
 * asagi kaydirip acilan alani buluyordu. Uzun listelerde acilan bolum
 * ekranin metrelerce altinda kaliyor.
 *
 * =========================================================================
 * NEDEN TEK YERDE
 * =========================================================================
 * Brief: "Bu davranisi tek bir yardimciya bagla, her sayfada ayni
 * calissin." Her sayfa kendi `scrollIntoView` cagrisini yazsaydi
 * davranis sayfadan sayfaya degisirdi (kimi ani, kimi yumusak, kimi
 * ustten pay birakan) — ve hareket-azaltma kurali birinde unutulurdu.
 *
 * =========================================================================
 * UC KARAR
 * =========================================================================
 * 1. `requestAnimationFrame` ILE BEKLER. Acilan alan `setState`ten SONRA
 *    DOM'a girer; ayni turda kaydirmaya calismak, HENUZ VAR OLMAYAN bir
 *    ogeye kaydirmakti. Iki kare bekleniyor: birincisi React'in cizimi,
 *    ikincisi duzenin oturmasi.
 *
 * 2. HAREKET AZALTMADA ANI. `prefers-reduced-motion` aciksa `behavior`
 *    `auto` olur — kaydirma YINE YAPILIR (kullanici alani gormeli), ama
 *    animasyonsuz.
 *
 * 3. ODAK DEGISTIRILMEZ. Kaydirmak bir gorunum islemidir; odagi zorla
 *    tasimak, klavye kullanicisini kendi bulundugu yerden koparirdi.
 *    Acilan alanin odagi gerekiyorsa cagiran ayrica verir.
 */
import { useCallback, useRef } from "react";

/** Ustte birakilan pay (px) — yapiskan baslik alani icin. */
const UST_PAY = 84;

function hareketAzaltilmis(): boolean {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}

/** Bir ogeyi gorunume yumusakca getirir. */
export function ogeyeKaydir(oge: HTMLElement | null): void {
  if (!oge) return;
  const ust = oge.getBoundingClientRect().top + window.scrollY - UST_PAY;
  window.scrollTo({
    top: Math.max(0, ust),
    behavior: hareketAzaltilmis() ? "auto" : "smooth",
  });
}

/**
 * Acilan alani gorunume getiren kanca.
 *
 * Kullanim:
 *   const { ref, kaydir } = useAcilinca();
 *   ...
 *   <Dugme onClick={() => { setDetay(x); kaydir(); }}>Detay</Dugme>
 *   {detay && <div ref={ref}>...</div>}
 */
export function useAcilinca<T extends HTMLElement = HTMLDivElement>(): {
  ref: React.RefObject<T>;
  kaydir: () => void;
} {
  const ref = useRef<T>(null);

  const kaydir = useCallback(() => {
    // IKI KARE: birincisinde React cizer, ikincisinde duzen oturur.
    // Tek karede olcum yaparsak acilan alanin yuksekligi henuz 0 olur ve
    // hedef konum yanlis hesaplanir.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => ogeyeKaydir(ref.current));
    });
  }, []);

  return { ref, kaydir };
}
