"use client";

/**
 * (P223 §4) Recharts CUBUK/CIZGI/YATAY — pastanin yaninda AYRI dosya.
 *
 * `grafik-pasta.tsx` ile ayni gerekce: `next/dynamic` karari sahnenin
 * DISINDA verilmeli, yoksa tembel yukleme hicbir sey kazandirmaz.
 *
 * BU DOSYA ERISILEBILIRLIK TASIMAZ: cagiran (`grafik.tsx`) cizimi
 * `aria-hidden` yapar ve rakamlari bir tabloda verir — yani renk TEK
 * BASINA hicbir zaman anlam tasimaz.
 */
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from "recharts";

import { useHareket } from "@/lib/hareket";

export type CubukTuru = "cubuk" | "cizgi" | "yatay";

// (P161) UCLUDE DIZE YAZILMAZ: sabit-metin taramasi JSX/ifade icindeki
// her dizeyi cevrilmemis metin adayi sayar. Bunlar RECHARTS YERLESIM
// DEGERI, kullaniciya gorunen metin degil — adli sabite alinir.
const DUZEN_DIKEY = "vertical" as const;
const DUZEN_YATAY = "horizontal" as const;

const EKSEN = {
  stroke: "var(--yz-text-3)",
  fontSize: 11,
} as const;

export function Cubuk({
  dilimler,
  palet,
  tur,
}: {
  dilimler: { ad: string; deger: number }[];
  palet: string[];
  tur: CubukTuru;
}) {
  const hareketVar = useHareket();
  const ortak = {
    data: dilimler,
    margin: { top: 8, right: 8, bottom: 4, left: 4 },
  };

  if (tur === "cizgi") {
    return (
      <ResponsiveContainer width="100%" height={220}>
        <LineChart {...ortak}>
          <CartesianGrid stroke="var(--yz-border)" strokeDasharray="3 3" />
          <XAxis dataKey="ad" tick={EKSEN} stroke="var(--yz-border)" />
          <YAxis tick={EKSEN} stroke="var(--yz-border)" width={44} />
          <Line
            type="monotone"
            dataKey="deger"
            stroke={palet[0]}
            strokeWidth={2}
            // NOKTALAR CIZILIR: tek basina bir cizgi, hangi noktanin
            // gercek olcum oldugunu gostermez (aylik veride onemli).
            dot={{ r: 3, fill: palet[0] }}
            isAnimationActive={hareketVar}
            animationDuration={520}
          />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  // YATAY: kova/yaslandirma gibi UZUN ETIKETLI veriler icin. Dikey
  // cubukta "90+ gun gecikmis" etiketi ya doner ya kirpilir.
  const yatay = tur === "yatay";
  return (
    <ResponsiveContainer width="100%" height={Math.max(220, dilimler.length * 34)}>
      <BarChart {...ortak} layout={yatay ? DUZEN_DIKEY : DUZEN_YATAY}>
        <CartesianGrid stroke="var(--yz-border)" strokeDasharray="3 3" />
        {yatay ? (
          <>
            <XAxis type="number" tick={EKSEN} stroke="var(--yz-border)" />
            <YAxis
              type="category"
              dataKey="ad"
              tick={EKSEN}
              stroke="var(--yz-border)"
              width={110}
            />
          </>
        ) : (
          <>
            <XAxis dataKey="ad" tick={EKSEN} stroke="var(--yz-border)" />
            <YAxis tick={EKSEN} stroke="var(--yz-border)" width={44} />
          </>
        )}
        <Bar
          dataKey="deger"
          fill={palet[0]}
          radius={yatay ? [0, 4, 4, 0] : [4, 4, 0, 0]}
          isAnimationActive={hareketVar}
          animationDuration={520}
        />
      </BarChart>
    </ResponsiveContainer>
  );
}
