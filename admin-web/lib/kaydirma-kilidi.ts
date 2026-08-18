"use client";

/**
 * (P169 §3) ARKA PLAN KAYDIRMA KILIDI — TEK YERDE.
 *
 * =========================================================================
 * NEDEN TOPLANDI
 * =========================================================================
 * Ayni is uc yerde uc FARKLI sekilde yapiliyordu:
 *
 *   * `Modal`   : yalniz `overflow: hidden`  -> iOS Safari'de govde YINE kayar,
 *   * `Cekmece` : kilit HIC YOK             -> yan panel aciken sayfa kayiyordu,
 *   * kabuk cekmecesi: dogru surum (P169).
 *
 * Uc kopyayi ayri ayri duzeltmek, dorduncu ortu bileseninde ayni hatanin
 * tekrar yazilmasini engellemezdi.
 *
 * =========================================================================
 * `overflow: hidden` NEDEN YETMEZ
 * =========================================================================
 * iOS Safari govde tasmasini yok sayar ve dokunmayla kaydirmayi surdurur.
 * Calisan tek yol govdeyi `position: fixed` yapip kaydirma konumunu
 * NEGATIF `top` ile korumak; kapaninca konumu geri koymak da sayfanin
 * BASA ATLAMASINI engeller (kilidin kendisi kadar onemli, cunku uzun bir
 * listede acilan modali kapatan kullanici yerini kaybederdi).
 *
 * =========================================================================
 * IC ICE ACILANLAR SAYILIR
 * =========================================================================
 * Cekmeceden modal acilabiliyor. Sayac olmasaydi ICTEKI kapaninca kilit
 * cozulur, DISTAKI hala aciken sayfa arkada kaymaya baslardi. Ilk kilit
 * kurar, son kilit cozer.
 */
import { useEffect } from "react";

let sayac = 0;
let kaydirma = 0;
let eski: {
  overflow: string;
  position: string;
  top: string;
  width: string;
} | null = null;

function kilitle(): void {
  sayac += 1;
  if (sayac > 1) return;
  const govde = document.body;
  kaydirma = window.scrollY;
  eski = {
    overflow: govde.style.overflow,
    position: govde.style.position,
    top: govde.style.top,
    width: govde.style.width,
  };
  govde.style.overflow = "hidden";
  govde.style.position = "fixed";
  govde.style.top = `-${kaydirma}px`;
  // `width: 100%` ZORUNLU: `position: fixed` govdeyi icerigine gore
  // daraltir ve duzen bir an icin ZIPLARDI.
  govde.style.width = "100%";
}

function coz(): void {
  sayac = Math.max(0, sayac - 1);
  if (sayac > 0 || !eski) return;
  const govde = document.body;
  govde.style.overflow = eski.overflow;
  govde.style.position = eski.position;
  govde.style.top = eski.top;
  govde.style.width = eski.width;
  eski = null;
  window.scrollTo(0, kaydirma);
}

/** `acik` true oldugu surece govde kaydirmasini kilitler. */
export function useKaydirmaKilidi(acik: boolean): void {
  useEffect(() => {
    if (!acik) return;
    kilitle();
    return coz;
  }, [acik]);
}
