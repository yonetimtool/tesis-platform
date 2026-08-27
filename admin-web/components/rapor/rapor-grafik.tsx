"use client";

// (P181 Bölüm 8) RAPOR GRAFİĞİ — recharts. Katalog `grafik` yapılandırması +
// tablo satırları. ERİŞİLEBİLİRLİK: renk TEK sinyal değil — eksen etiketleri,
// legend ve tooltip değerleri bilgiyi ayrıca taşır. VERİ YOKSA "veri yok"
// durumu çizilir (boş grafik değil). BÜYÜK VERİ örneklenir (tarayıcı kilitlenmesin).

import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { useHareket } from "@/lib/hareket";
import { useT } from "@/lib/i18n/kullan";
import type { RaporGrafikTanimi, RaporTablosu } from "@/components/rapor/rapor-modali";

// Erişilebilir, birbirinden ayırt edilebilir palet (mavi/turuncu/yeşil/altın/mor).
// Renk tek başına bilgi taşımaz; legend + eksen etiketi eşlik eder.
const PALET = ["#5b8def", "#e0663a", "#3aa576", "#c9a227", "#8b5cf6", "#0ea5e9"];

// Grafikte en çok bu kadar nokta; aşılırsa eşit aralıkla örneklenir.
const AZAMI_NOKTA = 60;

function ornekle<T>(satirlar: T[]): { veri: T[]; orneklendi: boolean } {
  if (satirlar.length <= AZAMI_NOKTA) return { veri: satirlar, orneklendi: false };
  const adim = Math.ceil(satirlar.length / AZAMI_NOKTA);
  const veri = satirlar.filter((_, i) => i % adim === 0);
  return { veri, orneklendi: true };
}

function sayi(v: unknown): number {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : 0;
}

export function RaporGrafik({
  grafik,
  tablo,
}: {
  grafik: RaporGrafikTanimi;
  tablo: RaporTablosu;
}) {
  const t = useT();
  const hareketVar = useHareket();

  // Sütun kimliği -> başlık (legend/eksen etiketi için) ve "kurus" mu.
  const baslikOf = (anahtar: string) =>
    tablo.sutunlar.find((s) => s.anahtar === anahtar)?.baslik ?? anahtar;
  const kurusMu = (anahtar: string) =>
    tablo.sutunlar.find((s) => s.anahtar === anahtar)?.tip === "kurus";

  if (!tablo.satirlar.length) {
    return (
      <div
        className="flex items-center justify-center rounded-kart border"
        style={{
          height: 120,
          borderColor: "var(--yz-border)",
          color: "var(--yz-text-2)",
          background: "var(--yz-surface-1)",
        }}
      >
        {t("raporGrafikVeriYok")}
      </div>
    );
  }

  // kurus serileri TL'ye çevrilir (okunur eksen); x etiketi olduğu gibi.
  const { veri: hamVeri, orneklendi } = ornekle(tablo.satirlar);
  const veri = hamVeri.map((satir) => {
    const nokta: Record<string, unknown> = { [grafik.x]: satir[grafik.x] };
    for (const seri of grafik.seriler) {
      const ham = sayi(satir[seri]);
      nokta[seri] = kurusMu(seri) ? ham / 100 : ham;
    }
    return nokta;
  });

  const eksenSecenek = { tick: { fill: "var(--yz-text-2)", fontSize: 11 } };
  const ortak = (
    <>
      <CartesianGrid strokeDasharray="3 3" stroke="var(--yz-border)" />
      <XAxis dataKey={grafik.x} {...eksenSecenek} />
      <YAxis {...eksenSecenek} width={64} />
      <Tooltip />
      <Legend />
    </>
  );

  return (
    <div className="space-y-1">
      <ResponsiveContainer width="100%" height={260}>
        {grafik.tip === "sutun" ? (
          <BarChart data={veri}>
            {ortak}
            {grafik.seriler.map((seri, i) => (
              <Bar
                key={seri}
                dataKey={seri}
                name={baslikOf(seri)}
                fill={PALET[i % PALET.length]}
                isAnimationActive={hareketVar}
              />
            ))}
          </BarChart>
        ) : grafik.tip === "pasta" ? (
          <PieChart>
            <Tooltip />
            <Legend />
            <Pie
              data={veri}
              dataKey={grafik.seriler[0]}
              nameKey={grafik.x}
              outerRadius={90}
              isAnimationActive={hareketVar}
              label
            >
              {veri.map((_, i) => (
                <Cell key={i} fill={PALET[i % PALET.length]} />
              ))}
            </Pie>
          </PieChart>
        ) : (
          <LineChart data={veri}>
            {ortak}
            {grafik.seriler.map((seri, i) => (
              <Line
                key={seri}
                type="monotone"
                dataKey={seri}
                name={baslikOf(seri)}
                stroke={PALET[i % PALET.length]}
                dot={false}
                isAnimationActive={hareketVar}
              />
            ))}
          </LineChart>
        )}
      </ResponsiveContainer>
      {orneklendi && (
        <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
          {t("raporGrafikOrneklem", { n: veri.length })}
        </p>
      )}
    </div>
  );
}
