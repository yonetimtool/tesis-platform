"use client";

/**
 * (P160 / Asama 3) GRAFIK KARTI.
 *
 * =========================================================================
 * NEDEN BU BILESEN VAR — VE NEDEN BU KADAR KUCUK
 * =========================================================================
 * Brief bir "ChartCard" istiyor. Recharts zaten kurulu; buradaki katman
 * onu SARMAK icin degil, uc karari TEK YERDE tutmak icin var:
 *
 *  1. RENK PALETI TEMADAN GELIR. Recharts'a renk vermezseniz kendi
 *     varsayilanlarini kullanir ve koyu temada okunamayan tonlar cikar.
 *     Paletimiz `--yz-*-edge` ailesidir: bunlar ANLAMLI GRAFIK esigi
 *     (3.0, WCAG 1.4.11) icin olculmustu ve grafik tam olarak odur.
 *  2. GRAFIK TEK BASINA VERI DEGILDIR. Bir dilim rengi hicbir sey
 *     soylemez; bu yuzden bilesen HER ZAMAN bir `<table>` de cizer
 *     (gorsel olarak gizli). Ekran okuyucu ve yazdirma ciktisi rakamlari
 *     boyle alir — grafigin kendisi `aria-hidden`dir.
 *  3. VERI YOKSA GRAFIK CIZILMEZ. Bos bir pasta, "sifir" demek yerine
 *     bozuk gorunur.
 *
 * SUNUCU-TARAFI CIZIM YOK: Recharts olcum icin DOM'a ihtiyac duyar;
 * `ssr:false` ile tembel yuklenir, boylece ana pakete de girmez.
 */
import dynamic from "next/dynamic";
import { useId, type ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";

import { Kart } from "./yuzey";
import { BosDurum } from "./durumlar";

export interface GrafikDilimi {
  /** Gorunen ad — SUNUCU VERISI olabilir, cevrilmez. */
  ad: string;
  /** Cizilecek deger. */
  deger: number;
}

/** Palet: anlamli grafik tonlari (3.0 esigi icin olculdu). */
const PALET = [
  "var(--yz-accent)",
  "var(--yz-success-edge)",
  "var(--yz-warning-edge)",
  "var(--yz-danger-edge)",
  "var(--yz-text-2)",
];

// Recharts DOM olcumune bagli — tembel yuklenir ve ana pakete girmez.
const Pasta = dynamic(() => import("./grafik-pasta").then((m) => m.Pasta), {
  ssr: false,
  loading: () => <div style={{ height: 220 }} />,
});

export function Grafik({
  baslik,
  dilimler,
  bicimle,
  bosBaslik,
  eylem,
}: {
  baslik: string;
  dilimler: GrafikDilimi[];
  /** Degeri metne cevirir (para/yuzde). Verilmezse duz sayi. */
  bicimle?: (n: number) => string;
  bosBaslik: string;
  eylem?: ReactNode;
}) {
  const t = useT();
  const tabloId = useId();
  const yaz = bicimle ?? ((n: number) => String(n));

  return (
    <Kart>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{baslik}</h2>
        {eylem}
      </div>

      {dilimler.length === 0 ? (
        <BosDurum baslik={bosBaslik} />
      ) : (
        <>
          {/* GRAFIK DEKORDUR: rakamlar asagidaki tabloda. */}
          <div aria-hidden="true">
            <Pasta dilimler={dilimler} palet={PALET} />
          </div>

          {/* RAKAMLAR — gorsel olarak grafigin altinda, ekran okuyucu icin
              TEK gercek kaynak. Gizlemek yerine GOSTERILIYOR: bir dagilim
              tablosu zaten okunmak istenen seydir. */}
          <table id={tabloId} className="mt-3 w-full border-collapse">
            <caption className="sr-only">{baslik}</caption>
            <tbody>
              {dilimler.map((d, i) => (
                <tr key={d.ad} style={{ borderTop: "1px solid var(--yz-border)" }}>
                  <th
                    scope="row"
                    className="py-1.5 text-start font-normal"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  >
                    <span className="inline-flex items-center gap-2">
                      <span
                        aria-hidden="true"
                        className="inline-block h-2.5 w-2.5 rounded-full"
                        style={{ background: PALET[i % PALET.length] }}
                      />
                      {d.ad}
                    </span>
                  </th>
                  <td
                    className="py-1.5 text-end tabular-nums"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
                  >
                    {yaz(d.deger)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="sr-only">{t("grafikTabloNotu")}</p>
        </>
      )}
    </Kart>
  );
}
