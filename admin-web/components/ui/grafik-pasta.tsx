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
import { Cell, Pie, PieChart, ResponsiveContainer } from "recharts";

export function Pasta({
  dilimler,
  palet,
}: {
  dilimler: { ad: string; deger: number }[];
  palet: string[];
}) {
  return (
    <ResponsiveContainer width="100%" height={220}>
      <PieChart>
        <Pie
          data={dilimler}
          dataKey="deger"
          nameKey="ad"
          innerRadius={55}
          outerRadius={90}
          // Animasyon KAPALI: `prefers-reduced-motion` ayarini Recharts
          // okumaz ve donen bir pasta o ayari acan kullanici icin tam da
          // kacinilmasi gereken sey.
          isAnimationActive={false}
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
