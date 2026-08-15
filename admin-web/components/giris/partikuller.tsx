"use client";

/**
 * (P162) PARTIKUL ALANI — tek canvas, DOM'da yuzlerce oge YOK.
 *
 * =========================================================================
 * NEDEN CANVAS
 * =========================================================================
 * Sartname §34 acikca "yuzlerce DOM particle" kullanmayi yasakliyor. 80
 * partikulu 80 `<div>` ile cizmek, her karede 80 stil yazmasi ve 80 katman
 * demek; canvas'ta ayni is TEK bir DOM ogesi ve tek bir cizim cagrisi.
 *
 * =========================================================================
 * DERINLIK: yaklasan ve uzaklasan partikuller (§7)
 * =========================================================================
 * Her partikulun bir `z` degeri var (0 uzak, 1 yakin). `z` yaricapi,
 * opakligi ve YATAY HIZI belirler: yakin olan hizli gecer, uzak olan
 * yavas. Paralaks bu tek kuraldan dogar — ayri bir katman gerekmez.
 *
 * =========================================================================
 * TEMIZLIK (§37)
 * =========================================================================
 * `requestAnimationFrame` ve `resize` dinleyicisi cikista iptal edilir.
 * Sekme arka plana dusunce tarayici rAF'i zaten durdurur; ayrica
 * `visibilitychange` ile de duruyoruz — mobilde pil icin onemli.
 */
import { useEffect, useRef } from "react";

interface Partikul {
  x: number;
  y: number;
  z: number;
  hiz: number;
  faz: number;
}

/** Turkuaz/cyan tonlari — sartname §7. */
const RENKLER = [
  [101, 230, 224],
  [66, 216, 207],
  [24, 199, 192],
];

export function Partikuller({ adet }: { adet: number }) {
  const tuvalRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const tuval = tuvalRef.current;
    if (!tuval) return;
    const ctx = tuval.getContext("2d");
    if (!ctx) return;

    let en = 0;
    let boy = 0;
    let oran = 1;
    const parcaciklar: Partikul[] = [];

    function kur() {
      const t = tuvalRef.current;
      if (!t) return;
      // DPR TAVANI 2: retina bir ekranda 3x cizmek, ayni sahne icin dokuz
      // kat piksel demekti ve partikuller zaten yumusak.
      oran = Math.min(2, window.devicePixelRatio || 1);
      en = t.clientWidth;
      boy = t.clientHeight;
      t.width = Math.round(en * oran);
      t.height = Math.round(boy * oran);
      ctx!.setTransform(oran, 0, 0, oran, 0, 0);
    }

    function dogur(ilk: boolean): Partikul {
      const z = Math.random();
      return {
        x: ilk ? Math.random() * en : -10,
        y: Math.random() * boy,
        z,
        // Yakin partikul hizli, uzak yavas (derinlik).
        hiz: 0.08 + z * 0.42,
        faz: Math.random() * Math.PI * 2,
      };
    }

    kur();
    for (let i = 0; i < adet; i++) parcaciklar.push(dogur(true));

    let cerceve = 0;
    let duruyor = false;

    function kare(zaman: number) {
      ctx!.clearRect(0, 0, en, boy);
      for (const p of parcaciklar) {
        p.x += p.hiz;
        // Cok hafif dikey salinim: duz cizgide akan noktalar mekanik
        // duruyordu.
        const y = p.y + Math.sin(zaman / 2600 + p.faz) * (4 + p.z * 8);
        if (p.x > en + 10) {
          Object.assign(p, dogur(false));
          continue;
        }
        const r = 0.6 + p.z * 1.5;
        const [kr, kg, kb] = RENKLER[Math.floor(p.z * RENKLER.length) % RENKLER.length];
        ctx!.beginPath();
        ctx!.arc(p.x, y, r, 0, Math.PI * 2);
        ctx!.fillStyle = `rgba(${kr},${kg},${kb},${(0.10 + p.z * 0.30).toFixed(3)})`;
        ctx!.fill();
      }
      cerceve = requestAnimationFrame(kare);
    }

    cerceve = requestAnimationFrame(kare);

    const olcuGozcusu = () => kur();
    window.addEventListener("resize", olcuGozcusu);

    // ARKA PLANDA CIZME: sekme gizlenince dongu durur, geri gelince
    // devam eder. Tarayici rAF'i cogu zaman kendi durdurur ama garanti
    // degil (bazi masaustu tarayicilarda dusuk frekansta surer).
    function gorunurluk() {
      if (document.hidden) {
        if (!duruyor) {
          cancelAnimationFrame(cerceve);
          duruyor = true;
        }
      } else if (duruyor) {
        duruyor = false;
        cerceve = requestAnimationFrame(kare);
      }
    }
    document.addEventListener("visibilitychange", gorunurluk);

    return () => {
      cancelAnimationFrame(cerceve);
      window.removeEventListener("resize", olcuGozcusu);
      document.removeEventListener("visibilitychange", gorunurluk);
    };
  }, [adet]);

  return (
    <canvas
      ref={tuvalRef}
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 h-full w-full"
    />
  );
}
