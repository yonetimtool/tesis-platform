"use client";

// (P244 §3) FILTRE CUBUGU — dagilmis kontrolleri tek bir seride toplar.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Paylasilan bir filtre bileseni YOKTU. Sayfalar kendi
// `<div className="flex flex-wrap items-end gap-3">` sarmalini yaziyor
// (12 sayfada bu tam dize, digerlerinde varyasyonlari). Sonuc: arama
// alaninin genisligi, filtrelerin hizasi (`items-end` mi `items-center`
// mi), eylem dugmelerinin nereye dustugu ve seridin bir kutu icinde mi
// yoksa ciplak mi durdugu ekrandan ekrana degisiyor.
//
// Referansta serit HER ekranda ayni: solda arama, ortada filtreler,
// sagda eylemler; hepsi tek bir kutuda.
//
// ===========================================================================
// NEDEN "AKTIF FILTRE SAYISI" GOSTERILIYOR
// ===========================================================================
// Bos bir liste karsisinda kullanicinin ilk sorusu "kayit mi yok, yoksa
// ben mi suzduM" olur. Bu, P243 §6c'de bos durum metinlerine yazilan
// dersin aynisi — ama orada YALNIZ metin vardi. Serit, suzgecin ACIK
// oldugunu ve kac tane oldugunu SAYIYLA soyler ve tek dokunusla temizler.
import type { ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";

export function FiltreCubugu({
  arama,
  children,
  eylemler,
  aktifSayi = 0,
  onTemizle,
}: {
  /** Arama alani — `AramaAlani` beklenir; verilmezse yer tutmaz. */
  arama?: ReactNode;
  /** Secim/tarih filtreleri. */
  children?: ReactNode;
  /** Sagda duran eylemler (Yeni kayit, Disa aktar). */
  eylemler?: ReactNode;
  /** Kac filtre AKTIF — 0 ise temizle dugmesi cizilmez. */
  aktifSayi?: number;
  onTemizle?: () => void;
}) {
  const t = useT();
  return (
    <div
      className="mb-4 flex flex-wrap items-center gap-2 px-3 py-2.5"
      style={{
        background: "var(--yz-surface-1)",
        border: "var(--yz-border-w) solid var(--yz-border)",
        borderRadius: "var(--yz-radius-card)",
      }}
      role="search"
      aria-label={t("filtreCubugu")}
    >
      {/* ARAMA EN GENIS OGE: serit sikisinca once filtreler alt satira
          iner, arama alani ayakta kalir — en sik kullanilan kontrol odur. */}
      {arama ? <div className="min-w-[12rem] flex-1">{arama}</div> : null}
      {children}
      {aktifSayi > 0 && onTemizle ? (
        <button
          type="button"
          onClick={onTemizle}
          data-test="filtre-temizle"
          className="odak-ic inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 transition-colors hover:bg-[var(--yz-surface-2)]"
          style={{
            fontSize: "var(--yz-fs-sm)",
            color: "var(--yz-accent-ink)",
            border: "var(--yz-border-w) solid var(--yz-border)",
          }}
        >
          {/* SAYI METNIN ICINDE: "3 filtre acik" tek basina anlasilir;
              yalniz bir rozet rengiyle anlatmak, renk tek tasiyici
              olurdu. */}
          {t("filtreTemizle", { n: aktifSayi })}
        </button>
      ) : null}
      {eylemler ? (
        <div className="ms-auto flex flex-wrap items-center gap-2">{eylemler}</div>
      ) : null}
    </div>
  );
}
