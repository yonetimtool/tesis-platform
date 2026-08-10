"use client";

import { useId, useState } from "react";

import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 7.2) PAROLA ALANI — goster/gizle, TEK yerde.
 *
 * Brief: "WEB: tum parola alanlarina goster/gizle ikonu". Panelde ALTI
 * parola alani var (giris, kayit x2, kullanici olustur, tesis olustur,
 * entegrasyon sirri). Her birine ayri bir goz dugmesi yazmak ayni sekiz
 * satiri alti kez kopyalamak ve birinde `aria-label`i unutmak olurdu.
 *
 * TIP DEGISIR, DEGER DEGISMEZ: `type` `password` <-> `text` arasinda
 * gecer. Ikinci bir "acik metin" girdisi cizip degeri kopyalamak,
 * tarayicinin parola yoneticisiyle iliskiyi koparirdi (`autoComplete`
 * girdiye baglidir).
 *
 * DUGME `type="button"`: form icinde varsayilan `submit`tir ve goze
 * basmak formu GONDERIRDI.
 *
 * DUGME SEKMEYE GIRER (`tabIndex` kisilmadi): parolasini goremeyen
 * kullanici klavyeyle de kontrol edebilmeli. Durum `aria-pressed` ile
 * bildirilir — ekran okuyucu "gosteriliyor/gizli" duyar.
 */
export function ParolaAlani({
  value,
  onChange,
  className,
  autoComplete,
  minLength,
  required,
  placeholder,
  id,
  name,
  disabled,
}: {
  value: string;
  onChange: (v: string) => void;
  className?: string;
  autoComplete?: string;
  minLength?: number;
  required?: boolean;
  placeholder?: string;
  id?: string;
  name?: string;
  disabled?: boolean;
}) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const olusanId = useId();
  const girdiId = id ?? olusanId;

  return (
    <span className="relative block">
      <input
        id={girdiId}
        name={name}
        type={acik ? "text" : "password"}
        className={className}
        // Goz dugmesi metnin USTUNE binmesin: sag (RTL'de sol) ic bosluk.
        style={{ paddingInlineEnd: "2.5rem" }}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete={autoComplete}
        minLength={minLength}
        required={required}
        placeholder={placeholder}
        disabled={disabled}
      />
      <button
        type="button"
        onClick={() => setAcik((a) => !a)}
        // Alan kapaliyken goz de kapali: devre disi bir girdinin icerigini
        // acmak, kullaniciya duzenleyebilecegi izlenimi verirdi.
        disabled={disabled}
        aria-pressed={acik}
        aria-controls={girdiId}
        aria-label={acik ? t("parolaGizle") : t("parolaGoster")}
        // 44pt dokunma hedefi — kucuk bir goz ikonu parmakla isabet
        // ettirilemez.
        className="odak-ic absolute inset-y-0 end-0 flex h-full min-w-11 items-center justify-center px-2 text-metin-muted transition hover:text-metin-body"
      >
        <Goz acik={acik} />
      </button>
    </span>
  );
}

/** Ikon DEKORATIFTIR: anlami tasiyan sey dugmenin `aria-label`idir. */
function Goz({ acik }: { acik: boolean }) {
  const ortak = {
    width: 18,
    height: 18,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "aria-hidden": true,
  };
  return acik ? (
    <svg {...ortak}>
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" />
      <circle cx="12" cy="12" r="3" />
      <line x1="3" y1="21" x2="21" y2="3" />
    </svg>
  ) : (
    <svg {...ortak}>
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}
