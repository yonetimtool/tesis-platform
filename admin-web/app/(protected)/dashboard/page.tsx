"use client";

import { motion } from "framer-motion";
import useSWR from "swr";

import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AktifTur, Alarm, DashboardLive } from "@/lib/types";

const DURUM_STYLE: Record<string, string> = {
  bekliyor: "bg-amber-100 text-amber-800",
  tamamlandi: "bg-emerald-100 text-emerald-800",
  kacirildi: "bg-red-100 text-red-800",
};

function DurumRozet({ durum }: { durum: string }) {
  return (
    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${DURUM_STYLE[durum] ?? "bg-slate-100 text-slate-700"}`}>
      {durum}
    </span>
  );
}

function AlarmSatir({ alarm }: { alarm: Alarm }) {
  return (
    <li className="flex items-start justify-between gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2">
      <div>
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold text-slate-500">{alarm.tip}</span>
        </div>
        <p className="text-sm text-slate-800">{alarm.mesaj}</p>
      </div>
      <span className="shrink-0 text-xs text-muted">{formatDateTime(alarm.olusma_zamani)}</span>
    </li>
  );
}

// Kucuk yukari-kayan sirali giris (stagger). Yalnizca transform/opacity.
const grid = {
  hidden: {},
  show: { transition: { staggerChildren: 0.05 } },
};
const cell = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3, ease: [0.22, 1, 0.36, 1] as const } },
};

function StatCard({
  label,
  value,
  detail,
  tone = "default",
}: {
  label: string;
  value: number;
  detail: string;
  tone?: "default" | "teal" | "amber" | "red";
}) {
  const valueTone =
    tone === "teal"
      ? "text-brand-teal"
      : tone === "amber"
        ? "text-amber-600"
        : tone === "red"
          ? "text-red-600"
          : "text-ink";
  return (
    <motion.div
      variants={cell}
      whileHover={{ y: -2 }}
      transition={{ type: "spring", stiffness: 400, damping: 30 }}
      className="rounded-2xl border border-slate-200 bg-white p-5 shadow-card"
    >
      <div className="text-sm font-medium text-muted">{label}</div>
      <div className={`mt-2 text-3xl font-semibold tabular-nums tracking-tight ${valueTone}`}>
        {value}
      </div>
      <div className="mt-1 text-xs text-muted">{detail}</div>
    </motion.div>
  );
}

export default function DashboardPage() {
  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );

  const turlar = data?.aktif_turlar ?? [];
  const tamamlanan = turlar.filter((t) => t.durum === "tamamlandi").length;
  const bekleyen = turlar.filter((t) => t.durum === "bekliyor").length;
  const kacirilan = turlar.filter((t) => t.durum === "kacirildi").length;
  const alarmSayisi = data?.son_alarmlar.length ?? 0;

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold tracking-tight">Canlı Panel</h1>
        {data && (
          <span className="text-xs text-muted">
            Güncellendi: {formatDateTime(data.generated_at)} · otomatik yenilenir (15 sn)
          </span>
        )}
      </div>

      {error && (
        <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error.message}
        </p>
      )}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      <motion.div
        variants={grid}
        initial="hidden"
        animate="show"
        className="grid grid-cols-2 gap-4 lg:grid-cols-4"
      >
        <StatCard
          label="Bugünkü Turlar"
          value={turlar.length}
          detail={`${turlar.length} plan penceresi`}
          tone="default"
        />
        <StatCard
          label="Tamamlanan"
          value={tamamlanan}
          detail={turlar.length ? `${turlar.length} turdan` : "tur yok"}
          tone="teal"
        />
        <StatCard
          label="Bekleyen"
          value={bekleyen}
          detail={kacirilan ? `${kacirilan} kaçırılan` : "kaçırılan yok"}
          tone="amber"
        />
        <StatCard
          label="Aktif Alarm"
          value={alarmSayisi}
          detail={alarmSayisi ? "ilgilenilmeli" : "her şey yolunda"}
          tone={alarmSayisi ? "red" : "default"}
        />
      </motion.div>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Bugünkü Turlar</h2>
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Plan</th>
                  <th className="px-4 py-2.5 font-medium">Pencere</th>
                  <th className="px-4 py-2.5 font-medium">Durum</th>
                  <th className="px-4 py-2.5 font-medium">Okutulan / Beklenen</th>
                </tr>
              </thead>
              <tbody>
                {turlar.map((t: AktifTur) => (
                  <tr key={t.patrol_window_id} className="border-t border-slate-100">
                    <td className="px-4 py-2.5">{t.patrol_plan_ad ?? t.patrol_plan_id.slice(0, 8)}</td>
                    <td className="px-4 py-2.5 text-slate-600">
                      {formatDateTime(t.pencere_baslangic)} – {formatDateTime(t.pencere_bitis)}
                    </td>
                    <td className="px-4 py-2.5">
                      <DurumRozet durum={t.durum} />
                    </td>
                    <td className="px-4 py-2.5 tabular-nums text-slate-600">
                      {t.okutulan_checkpoint_sayisi ?? 0} / {t.beklenen_checkpoint_sayisi ?? 0}
                    </td>
                  </tr>
                ))}
                {data && turlar.length === 0 && (
                  <tr>
                    <td className="px-4 py-8 text-center text-muted" colSpan={4}>
                      Bugün için tur yok.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Son Alarmlar</h2>
        <ul className="space-y-2">
          {(data?.son_alarmlar ?? []).map((a, i) => (
            <AlarmSatir key={`${a.tip}-${a.olusma_zamani}-${i}`} alarm={a} />
          ))}
          {data && data.son_alarmlar.length === 0 && (
            <li className="rounded-2xl border border-slate-200 bg-white px-3 py-8 text-center text-muted shadow-card">
              Alarm yok.
            </li>
          )}
        </ul>
      </section>
    </div>
  );
}
