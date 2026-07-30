"use client";

import { motion } from "framer-motion";
import useSWR from "swr";

import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AktifTur, Alarm, DashboardLive } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

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
    <li className="flex flex-wrap items-start justify-between gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2">
      <div className="min-w-0 flex-1">
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
      ? "text-brand-tealInk"
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
  const t = useT();
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
        <h1 className="min-w-0 text-2xl font-semibold tracking-tight break-words">
          {t("kabukCanliPanel")}
        </h1>
        {data && (
          <span className="text-xs text-muted">
            {t("panelGuncellendiTam", { zaman: formatDateTime(data.generated_at) })}
          </span>
        )}
      </div>

      {error && (
        // CANLI BOLGE (tur 56): canli panel 15 sn'de bir yenilenir; hata
        // kutusu SONRADAN gelir ve `role="alert"` olmadan duyurulmaz.
        <p
          role="alert"
          className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          {error.message}
        </p>
      )}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      <motion.div
        variants={grid}
        initial="hidden"
        animate="show"
        className="grid grid-cols-1 gap-4 min-[420px]:grid-cols-2 lg:grid-cols-4"
      >
        <StatCard
          label={t("panelBugunkuTurlar")}
          value={turlar.length}
          detail={t("panelPlanPenceresi", { n: turlar.length })}
          tone="default"
        />
        <StatCard
          label={t("panelTamamlanan")}
          value={tamamlanan}
          detail={turlar.length ? t("panelTurdan", { n: turlar.length }) : t("panelTurYok")}
          tone="teal"
        />
        <StatCard
          label={t("panelBekleyen")}
          value={bekleyen}
          detail={kacirilan ? t("panelKacirilanN", { n: kacirilan }) : t("panelKacirilanYok")}
          tone="amber"
        />
        <StatCard
          label={t("panelAktifAlarm")}
          value={alarmSayisi}
          detail={alarmSayisi ? t("panelIlgilenilmeli") : t("panelHerSeyYolunda")}
          tone={alarmSayisi ? "red" : "default"}
        />
      </motion.div>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">{t("panelBugunkuTurlar")}</h2>
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
          <div className="odak-ic overflow-x-auto" tabIndex={0}>
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">{t("panelPlan")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("panelPencere")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("ortakDurum")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("panelOkutulanBeklenen")}</th>
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
                      {t("panelTurYokBugun")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">{t("panelSonAlarmlar")}</h2>
        <ul className="space-y-2">
          {(data?.son_alarmlar ?? []).map((a, i) => (
            <AlarmSatir key={`${a.tip}-${a.olusma_zamani}-${i}`} alarm={a} />
          ))}
          {data && data.son_alarmlar.length === 0 && (
            <li className="rounded-2xl border border-slate-200 bg-white px-3 py-8 text-center text-muted shadow-card">
              {t("panelAlarmYok")}
            </li>
          )}
        </ul>
      </section>
    </div>
  );
}
