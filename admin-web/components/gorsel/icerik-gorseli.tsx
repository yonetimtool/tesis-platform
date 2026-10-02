"use client";

// (P251 §5c) ORTAK ICERIK GORSELI — duyuru, etkinlik, rezervasyon alani.
//
// IKI BOY:
//   * `kucuk`  : listede satir/kart basinda kare kucuk resim (64 px).
//   * `buyuk`  : ayrintida 16:9 kapak.
//
// GORSEL YOKSA (ya da yuklenemezse) BOS CERCEVE CIZILMEZ (§5d):
//   * `kucuk` : icerigin turunu soyleyen sakin bir ikon kutusu — liste
//               hizasi bozulmaz, "gorsel kirik" izlenimi de verilmez.
//   * `buyuk` : HICBIR SEY cizilmez; ayrinti metinle baslar.
// Eski `Foto` bileseni src yokken kesik kenarli "Gorsel goruntulenemedi"
// kutusu ciziyordu: gorseli olmayan (istege bagli!) her kayit kirik
// gibi gorunuyordu.
import { useState } from "react";

export type GorselTuru = "duyuru" | "etkinlik" | "alan";

const IKON: Record<GorselTuru, string> = {
  duyuru: "M3 11v2a1 1 0 0 0 1 1h2l5 4V6L6 10H4a1 1 0 0 0-1 1Zm13-3a5 5 0 0 1 0 8",
  etkinlik: "M7 3v4M17 3v4M3 9h18M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z",
  alan: "M3 21h18M5 21V9l7-5 7 5v12M9 21v-6h6v6",
};

export function IcerikGorseli({
  url,
  alt,
  boy,
  tur,
}: {
  url?: string | null;
  alt: string;
  boy: "kucuk" | "buyuk";
  tur: GorselTuru;
}) {
  const [hata, setHata] = useState(false);
  const var_ = Boolean(url) && !hata;

  if (boy === "buyuk") {
    if (!var_) return null;
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url!}
        alt={alt}
        loading="lazy"
        decoding="async"
        onError={() => setHata(true)}
        data-test="icerik-gorseli-buyuk"
        className="aspect-[16/9] w-full rounded-lg object-cover"
        style={{ background: "var(--yz-surface-sunken)" }}
      />
    );
  }

  if (!var_) {
    return (
      <span
        aria-hidden="true"
        data-test="icerik-gorseli-yok"
        className="flex h-16 w-16 shrink-0 items-center justify-center rounded-lg"
        style={{ background: "var(--yz-surface-2)", color: "var(--yz-text-3)" }}
      >
        <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor"
          strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
          <path d={IKON[tur]} />
        </svg>
      </span>
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={url!}
      alt={alt}
      loading="lazy"
      decoding="async"
      onError={() => setHata(true)}
      data-test="icerik-gorseli-kucuk"
      className="h-16 w-16 shrink-0 rounded-lg object-cover"
      style={{ background: "var(--yz-surface-sunken)" }}
    />
  );
}
