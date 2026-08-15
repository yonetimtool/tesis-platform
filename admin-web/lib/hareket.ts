"use client";

/**
 * (P161) `useHareket` — HAREKET SERBEST MI?
 *
 * =========================================================================
 * NEDEN KANCA, framer-motion'un `MotionConfig`i VARKEN
 * =========================================================================
 * `MotionConfig reducedMotion="user"` yalniz framer-motion bilesenlerini
 * baglar. Depoda hareket ureten UC sey daha var ve hicbiri framer
 * degil:
 *
 *   * Recharts (`isAnimationActive`) — ayari OKUMAZ,
 *   * kendi yazdigimiz sayac (`useSayac`),
 *   * WebGL sahnesi.
 *
 * Bunlarin her biri ayri ayri `matchMedia` cagiriyordu; uc ayri kopya
 * demek, birinde kuralin unutulmasi demek. Tek kaynak burasi.
 *
 * =========================================================================
 * SUNUCUDA HAREKET VAR SAYILIR — VE BU BILINCLI
 * =========================================================================
 * `window` sunucuda yok. Baslangic degeri `true` cunku ilk kare sunucuda
 * ciziliyor ve `false` ile baslamak, hareketi acik olan kullanicida da
 * ilk kareyi hareketsiz cizip sonra ZIPLATIRDI. Tercih istemcide, ilk
 * etkiyle okunur.
 *
 * DEGISIMI IZLER: kullanici isletim sistemi ayarini sayfa aciktan
 * degistirebilir; `change` olayi olmadan uygulama eski karari tasirdi.
 */
import { useEffect, useState } from "react";

const SORGU = "(prefers-reduced-motion: reduce)";

export function useHareket(): boolean {
  const [hareket, setHareket] = useState(true);

  useEffect(() => {
    const mq = window.matchMedia?.(SORGU);
    if (!mq) return;
    const uygula = () => setHareket(!mq.matches);
    uygula();
    mq.addEventListener("change", uygula);
    return () => mq.removeEventListener("change", uygula);
  }, []);

  return hareket;
}

/** Sirali giris gecikmesi (sn) — brief: satirlar 30 ms arayla. */
export const SIRA_GECIKMESI = 0.03;
/** Sirali giriste en fazla bu kadar oge gecikir; sonrasi ayni anda gelir. */
export const SIRA_TAVANI = 12;
/** Kurumsal easing — hizli baslar, hedefte yumusar. */
export const YUMUSAK_EGRI = [0.22, 1, 0.36, 1] as const;

/**
 * Satir/kart sirali giris gecikmesi.
 *
 * TAVAN NEDEN VAR: 25 satirlik bir sayfada 30 ms'lik gecikme son satiri
 * 0.75 sn geciktirirdi — tablonun "yuklenmeye devam ettigi" izlenimi
 * verirdi. Ilk oniki satir sirayla, gerisi birlikte gelir.
 */
export function siraGecikmesi(indeks: number, hareketVar: boolean): number {
  if (!hareketVar) return 0;
  return Math.min(indeks, SIRA_TAVANI) * SIRA_GECIKMESI;
}
