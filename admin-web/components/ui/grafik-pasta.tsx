"use client";

/**
 * (P160) Recharts pasta — AYRI DOSYA, bilincli.
 *
 * `next/dynamic` karari sahnenin DISINDA verilmeli (3D yukleyicideki
 * ayrimin aynisi): ayni dosyada olsaydi modul zaten yuklenmis olurdu ve
 * tembel yukleme hicbir sey kazandirmazdi.
 *
 * BU DOSYA ERISILEBILIRLIK TASIMAZ: cagiran (`grafik.tsx`) ciziMi
 * `aria-hidden` yapar ve rakamlari bir tabloda verir.
 */
import { useHareket } from "@/lib/hareket";
import { Cell, Pie, PieChart, ResponsiveContainer } from "recharts";

export function Pasta({
  dilimler,
  palet,
}: {
  dilimler: { ad: string; deger: number }[];
  palet: string[];
}) {
  const hareketVar = useHareket();
  return (
    <ResponsiveContainer width="100%" height={220}>
      <PieChart>
        <Pie
          data={dilimler}
          dataKey="deger"
          nameKey="ad"
          innerRadius={55}
          outerRadius={90}
          // (P161) GIRIS ANIMASYONU ACILDI — AMA KOSULLU.
          //
          // Onceki surum animasyonu HERKESE kapatiyordu; gerekce dogruydu
          // (Recharts `prefers-reduced-motion`u okumaz) ama cozum fazla
          // genisti: ayari acmayan kullanici da hicbir giris hareketi
          // gormuyordu. Artik tercihi BIZ okuyoruz (`useHareket`) ve
          // karari Recharts'a veriyoruz.
          isAnimationActive={hareketVar}
          animationDuration={520}
          animationEasing="ease-out"
          stroke="var(--yz-metal-1)"
          strokeWidth={2}
        >
          {dilimler.map((d, i) => (
            <Cell key={d.ad} fill={palet[i % palet.length]} />
          ))}
        </Pie>
      </PieChart>
    </ResponsiveContainer>
  );
}
