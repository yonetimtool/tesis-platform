"use client";

/**
 * (P162) GIRIS SAHNESI — bes derinlik katmani + mouse paralaks.
 *
 * =========================================================================
 * KATMANLAR (sartname §9)
 * =========================================================================
 *   1. uzak / bulanik yorungeler   — en az hareket eder
 *   2. orta mesafe yorungeler
 *   3. parlayan dugumler + baglantilar
 *   4. suzulen partikuller
 *   5. ortam isiklari (aura)
 *
 * Paralaksta her katmanin katsayisi FARKLI; derinlik hissi tam olarak bu
 * farktan dogar. Hepsi ayni miktarda kaysaydi ortaya duz bir resmin
 * kaymasi cikardi.
 *
 * =========================================================================
 * PARALAKS: HER KAREDE `setState` YOK
 * =========================================================================
 * Mouse hareketi saniyede ~120 olay uretir. Her olayda React durumu
 * guncellemek, bu agacin tamamini saniyede 120 kez yeniden cizmekti.
 * Bunun yerine CSS OZEL DEGISKENLERI dogrudan DOM'a yaziliyor
 * (`--giris-px` / `--giris-py`) ve katmanlar onlari okuyor: React hicbir
 * sey cizmez, tarayici yalnizca bilesim yapar.
 *
 * Yazma da `requestAnimationFrame` ile bir kareye SIKISTIRILIR — olay
 * basina degil, kare basina bir yazma.
 *
 * MAX 10-20 px (sartname §8): katsayilar buna gore secildi ve en dis
 * katman bile 18 px'i asmaz.
 */
import { useEffect, useRef } from "react";

import { AURA_GRADYANI, VINYET_GRADYANI, ZEMIN_GRADYANI, paralaks } from "./stil";
import { Partikuller } from "./partikuller";
import { Yorungeler } from "./yorungeler";

// UCLUDE/PROPTA DIZE YAZILMAZ (depo kurali `sabit-metin`).
const GRUP_UZAK = "uzak" as const;
const GRUP_YAKIN = "yakin" as const;

/** Katman basina paralaks katsayisi (piksel). Sartname siniri: 10-20. */
const KAYMA = { uzak: 6, orta: 11, dugum: 16, isik: 8 } as const;

export function GirisSahnesi({
  hareketVar,
  mobil,
}: {
  hareketVar: boolean;
  mobil: boolean;
}) {
  const kokRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // PARALAKS MOBILDE YOK: dokunmatik cihazda mouse yok, olay dinlemek
    // bosuna. Hareket azaltmada da yok (sartname §33).
    if (!hareketVar || mobil) return;
    const kok = kokRef.current;
    if (!kok) return;

    let x = 0;
    let y = 0;
    let bekleyen = 0;

    function yaz() {
      bekleyen = 0;
      kok?.style.setProperty("--giris-px", x.toFixed(3));
      kok?.style.setProperty("--giris-py", y.toFixed(3));
    }

    function hareket(e: PointerEvent) {
      // -1 .. +1 araligina normalle.
      x = (e.clientX / window.innerWidth) * 2 - 1;
      y = (e.clientY / window.innerHeight) * 2 - 1;
      if (!bekleyen) bekleyen = requestAnimationFrame(yaz);
    }

    window.addEventListener("pointermove", hareket, { passive: true });
    return () => {
      window.removeEventListener("pointermove", hareket);
      if (bekleyen) cancelAnimationFrame(bekleyen);
    };
  }, [hareketVar, mobil]);

  // MOBILDE 10-30 PARTIKUL (sartname §31); masaustunde 80.
  const partikulAdedi = mobil ? 22 : 80;

  return (
    <div
      ref={kokRef}
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 overflow-hidden"
      style={{
        // Baslangic degerleri: paralaks hic calismasa da katmanlar
        // gecerli bir donusum degeri bulur.
        ["--giris-px" as string]: "0",
        ["--giris-py" as string]: "0",
        background: ZEMIN_GRADYANI,
      }}
    >
      {/* --- KATMAN 5: ORTAM ISIKLARI (§10) ---
          Cok buyuk, cok yumusak radial alanlar. `blur` YOK: 400 px'lik bir
          blur her karede pahali; radial gradyan zaten yumusak ve bedava. */}
      <div
        className={hareketVar ? "giris-nefes" : undefined}
        style={{
          position: "absolute",
          inset: "-10%",
          transform: paralaks(KAYMA.isik),
          background: AURA_GRADYANI,
        }}
      />

      {/* --- KATMAN 1: UZAK YORUNGELER ---
          ORTALAMA FLEX ILE, mutlak konumlandirmayla DEGIL. Iki gerekce:
          mutlak konum ozellikleri yon duyarli degildir (RTL kilidi hakli
          olarak yakaliyor), ve ortalama icin kullanilacak donusum,
          paralaks donusumuyle AYNI `transform` ozelligini paylasmak
          zorunda kalirdi. */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div
          className="aspect-square w-[190%] opacity-40 sm:w-[125%]"
          style={{
            // `filter: blur()` KALDIRILDI — olculdu: tam ekran bir
            // bulaniklik her karede yeniden hesaplaniyordu ve kare
            // suresinin buyuk bolumunu tek basina yiyordu. Uzaklik
            // hissi artik OPAKLIK ve CIZGI KALINLIGI ile veriliyor
            // (atmosfer perspektifi zaten boyle calisir).
            transform: paralaks(KAYMA.uzak),
          }}
        >
          <Yorungeler hareketVar={hareketVar} grup={GRUP_UZAK} />
        </div>
      </div>

      {/* --- KATMAN 2+3: ORTA MESAFE + DUGUMLER --- */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div
          className="aspect-square w-[150%] sm:w-[95%]"
          style={{
            transform: paralaks(KAYMA.dugum),
          }}
        >
          <Yorungeler hareketVar={hareketVar} grup={GRUP_YAKIN} />
        </div>
      </div>

      {/* --- KATMAN 4: PARTIKULLER ---
          Hareket azaltmada HIC cizilmez: sartname §33 "particle animation
          kapat" diyor. Sahne bozulmuyor cunku yorungeler ve isiklar
          duruyor. */}
      {hareketVar && <Partikuller adet={partikulAdedi} />}

      {/* Alt vinyet: form kartinin arkasindaki alani sakinlestirir, boylece
          arka plan formdan baskin cikmaz (§44). */}
      <div
        className="absolute inset-0"
        style={{
          background: VINYET_GRADYANI,
        }}
      />
    </div>
  );
}
