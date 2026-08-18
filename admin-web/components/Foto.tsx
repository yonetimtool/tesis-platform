"use client";

// TUR 35 — AG GORSELI + BASARISIZLIK HALI.
//
// Panel fotograflari kisa omurlu presigned URL ile gelir (900 sn). Sayfa acik
// kalirsa ya da obje silinmisse `<img>` BOZUK GORSEL ikonuna duser: kullanici
// icin anlamsiz bir kirik resim. Mobilde bu durum `errorBuilder` ile
// karsilanir (talep/duyuru/etkinlik gorselleri) — panelde karsiligi YOKTU.
//
// Not: fotografin kendisi yerine METIN gosterilir ve kutu AYNI olcuyu korur,
// boylece duzen kaymaz.

import { useState } from "react";

import { useT } from "@/lib/i18n/kullan";

export function Foto({
  src,
  alt,
  className,
}: {
  src?: string | null;
  alt: string;
  className?: string;
}) {
  const t = useT();
  const [hata, setHata] = useState(false);

  if (!src || hata) {
    return (
      <span
        // Yer tutucu da ANLAM tasir: ekran okuyucu "gorsel goruntulenemedi"
        // duyar, gorenler ayni kutuda metni okur.
        role="img"
        aria-label={`${alt} — ${t("gorselGosterilemedi")}`}
        className={`flex items-center justify-center border border-dashed border-slate-300 bg-yuzey-bg px-2 text-center text-[11px] leading-tight text-metin-muted dark:border-slate-600 dark:bg-slate-800 ${className ?? ""}`}
      >
        {t("gorselGosterilemedi")}
      </span>
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt={alt}
      // (P169 §6) TEMBEL + ESZAMANSIZ COZUM. Bu bilesen liste hucrelerinde
      // kullaniliyor: yavas 4G'de ekranda GORUNMEYEN onlarca gorseli
      // pesinen indirmek, ilk anlamli cizimi geciktiren en buyuk kalemdi.
      loading="lazy"
      decoding="async"
      className={className}
      onError={() => setHata(true)}
    />
  );
}
