"use client";

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
  const acil = alarm.tip === "acil_durum";
  return (
    <li
      className={`flex items-start justify-between gap-3 rounded-lg border px-3 py-2 ${
        acil ? "border-red-300 bg-red-50" : "border-slate-200 bg-white"
      }`}
    >
      <div>
        <div className="flex items-center gap-2">
          <span className={`text-xs font-semibold ${acil ? "text-red-700" : "text-slate-500"}`}>
            {acil ? "ACİL DURUM" : alarm.tip}
          </span>
        </div>
        <p className="text-sm text-slate-800">{alarm.mesaj}</p>
      </div>
      <span className="shrink-0 text-xs text-muted">{formatDateTime(alarm.olusma_zamani)}</span>
    </li>
  );
}

export default function DashboardPage() {
  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Canlı Panel</h1>
        {data && (
          <span className="text-xs text-muted">
            Güncellendi: {formatDateTime(data.generated_at)} · otomatik yenilenir (15 sn)
          </span>
        )}
      </div>

      {error && (
        <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error.message}</p>
      )}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Bugünkü Turlar</h2>
        <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-3 py-2 font-medium">Plan</th>
                <th className="px-3 py-2 font-medium">Pencere</th>
                <th className="px-3 py-2 font-medium">Durum</th>
                <th className="px-3 py-2 font-medium">Okutulan / Beklenen</th>
              </tr>
            </thead>
            <tbody>
              {(data?.aktif_turlar ?? []).map((t: AktifTur) => (
                <tr key={t.patrol_window_id} className="border-t border-slate-100">
                  <td className="px-3 py-2">{t.patrol_plan_ad ?? t.patrol_plan_id.slice(0, 8)}</td>
                  <td className="px-3 py-2 text-slate-600">
                    {formatDateTime(t.pencere_baslangic)} – {formatDateTime(t.pencere_bitis)}
                  </td>
                  <td className="px-3 py-2">
                    <DurumRozet durum={t.durum} />
                  </td>
                  <td className="px-3 py-2 text-slate-600">
                    {t.okutulan_checkpoint_sayisi ?? 0} / {t.beklenen_checkpoint_sayisi ?? 0}
                  </td>
                </tr>
              ))}
              {data && data.aktif_turlar.length === 0 && (
                <tr>
                  <td className="px-3 py-6 text-center text-muted" colSpan={4}>
                    Bugün için tur yok.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Son Alarmlar</h2>
        <ul className="space-y-2">
          {(data?.son_alarmlar ?? []).map((a, i) => (
            <AlarmSatir key={`${a.tip}-${a.olusma_zamani}-${i}`} alarm={a} />
          ))}
          {data && data.son_alarmlar.length === 0 && (
            <li className="rounded-lg border border-slate-200 bg-white px-3 py-6 text-center text-muted">
              Alarm yok.
            </li>
          )}
        </ul>
      </section>
    </div>
  );
}
