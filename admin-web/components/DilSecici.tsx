"use client";

// Dil secici (tur 17) — panel kabugunda tema dugmesinin yanindadir.
//
// Diller HER ZAMAN kendi dilinde yazar ("العربية", "Русский"): cevrilirse
// secici islevini yitirir — kullanici anlamadigi bir dilde kendi dilini
// arayamaz. Mobil taraftaki `AppDil.adKendiDilinde` ile ayni karar.
//
// Secim cookie'ye yazilir (bkz. `lib/i18n/diller.ts`): sunucu bileseni ilk
// boyamada `<html lang/dir>` icin, BFF ise `Accept-Language` basligi icin
// ayni degeri okur. Yani tek secim hem paneli hem SUNUCU metinlerini
// (hata mesajlari, icerik cevirisi) ayni dile getirir.

import { useEffect, useRef, useState } from "react";

import { DILLER, DIL_ADLARI, type Dil } from "@/lib/i18n/diller";
import { useI18n } from "@/lib/i18n/kullan";

export function DilSecici() {
  const { dil, t, dilDegistir } = useI18n();
  const [acik, setAcik] = useState(false);
  const kutu = useRef<HTMLDivElement>(null);

  // Disari tiklayinca kapat (menu kalici acik kalmasin).
  useEffect(() => {
    if (!acik) return;
    function disariTikla(e: MouseEvent) {
      if (!kutu.current?.contains(e.target as Node)) setAcik(false);
    }
    document.addEventListener("mousedown", disariTikla);
    return () => document.removeEventListener("mousedown", disariTikla);
  }, [acik]);

  function sec(yeni: Dil) {
    dilDegistir(yeni);
    setAcik(false);
    // Sunucu bilesenleri (ve BFF basligi) yeni cookie ile yeniden uretilsin.
    // `router.refresh()` yerine tam yenileme: `<html lang/dir>` ve sunucudan
    // gelen metinlerin HEPSI tek adimda tutarli hale gelir.
    window.location.reload();
  }

  return (
    <div className="relative" ref={kutu}>
      <button
        onClick={() => setAcik((a) => !a)}
        title={t("dilSeciciBaslik")}
        aria-label={t("dilSecici")}
        aria-haspopup="listbox"
        aria-expanded={acik}
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-metin-body transition hover:bg-slate-100"
      >
        <span aria-hidden>🌐</span> {DIL_ADLARI[dil]}
      </button>

      {acik && (
        <ul
          role="listbox"
          // `end-0`: RTL'de de dogru kenara yaslanir (`end-0` Arapcada
          // menuyu ekranin disina iterdi).
          className="absolute end-0 z-50 mt-1 w-40 overflow-hidden rounded-lg border kart-kenar bg-white py-1 shadow-lift"
        >
          {DILLER.map((d) => (
            <li key={d}>
              <button
                role="option"
                aria-selected={d === dil}
                onClick={() => sec(d)}
                className={`block w-full px-3 py-1.5 text-start text-sm transition hover:bg-slate-100 ${
                  d === dil ? "font-semibold text-brand-tealInk" : "text-metin-body"
                }`}
              >
                {DIL_ADLARI[d]}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
