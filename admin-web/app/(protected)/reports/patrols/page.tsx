"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion } from "@/components/form";
import { ReportsTabs } from "@/components/ReportsTabs";
import { fetchAllItems } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { PatrolPlanList, PatrolWindowListResponse, PatrolWindowRow } from "@/lib/types";

const LIMIT = 20;
const DURUM_STYLE: Record<string, string> = {
  tamamlandi: "bg-emerald-100 text-emerald-800",
  kacirildi: "bg-red-100 text-red-800",
  bekliyor: "bg-amber-100 text-amber-800",
};

function toIso(local: string): string {
  if (!local) return "";
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? "" : d.toISOString();
}

function csvDownload(filename: string, rows: string[][]): void {
  const esc = (c: string) => (/[",\n]/.test(c) ? `"${c.replace(/"/g, '""')}"` : c);
  const csv = rows.map((r) => r.map(esc).join(",")).join("\n");
  const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function PatrolReportPage() {
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [durum, setDurum] = useState("");
  const [planId, setPlanId] = useState("");
  const [committed, setCommitted] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  const { data: plans } = useSWR<PatrolPlanList>("/api/patrol-plans?limit=200&offset=0", jsonFetcher);

  function buildFilters(): string {
    const qs = new URLSearchParams();
    const b = toIso(bas);
    if (b) qs.set("baslangic", b);
    const e = toIso(bit);
    if (e) qs.set("bitis", e);
    if (durum) qs.set("durum", durum);
    if (planId) qs.set("patrol_plan_id", planId);
    return qs.toString();
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setCommitted(buildFilters());
    setOffset(0);
  }

  const key =
    committed !== null
      ? `/api/patrol-windows?${[committed, `limit=${LIMIT}`, `offset=${offset}`]
          .filter(Boolean)
          .join("&")}`
      : null;
  const { data, error, isLoading } = useSWR<PatrolWindowListResponse>(key, jsonFetcher);

  const oran =
    data && data.ozet.toplam > 0
      ? `% ${Math.floor((data.ozet.tamamlandi * 100) / data.ozet.toplam)}`
      : "—";

  async function exportCsv() {
    if (committed === null) return;
    const items = await fetchAllItems<PatrolWindowRow>(`/api/patrol-windows?${committed}`);
    const rows: string[][] = [
      ["Plan", "Baslangic", "Bitis", "Durum", "Okutulan", "Beklenen"],
    ];
    for (const w of items) {
      rows.push([
        w.plan_adi ?? "",
        w.pencere_baslangic,
        w.pencere_bitis,
        w.durum,
        String(w.okutulan_checkpoint_sayisi),
        String(w.beklenen_checkpoint_sayisi),
      ]);
    }
    csvDownload("tur-gecmisi.csv", rows);
  }

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <PageHeader title="Tur Geçmişi Raporu" />

      <motion.form {...panelMotion} onSubmit={submit} className={`flex flex-wrap items-end gap-3 ${panelCls}`}>
        <div className="w-52">
          <Field label="Başlangıç" hint="Yerel saat (opsiyonel)">
            <input type="datetime-local" className={inputCls} value={bas} onChange={(e) => setBas(e.target.value)} />
          </Field>
        </div>
        <div className="w-52">
          <Field label="Bitiş" hint="Yerel saat (opsiyonel)">
            <input type="datetime-local" className={inputCls} value={bit} onChange={(e) => setBit(e.target.value)} />
          </Field>
        </div>
        <div className="w-44">
          <Field label="Durum">
            <select className={inputCls} value={durum} onChange={(e) => setDurum(e.target.value)}>
              <option value="">Tümü</option>
              <option value="tamamlandi">Tamamlandı</option>
              <option value="kacirildi">Kaçırıldı</option>
              <option value="bekliyor">Bekliyor</option>
            </select>
          </Field>
        </div>
        <div className="w-52">
          <Field label="Plan (opsiyonel)">
            <select className={inputCls} value={planId} onChange={(e) => setPlanId(e.target.value)}>
              <option value="">Tümü</option>
              {(plans?.items ?? []).map((p) => (
                <option key={p.id} value={p.id}>
                  {p.ad}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <button type="submit" className={btnPrimary}>
          Raporu getir
        </button>
      </motion.form>

      {error && <ErrorBox message={error.message} />}
      {committed === null && (
        <p className="text-sm text-muted">Filtre seçip Raporu getir butonuna basın.</p>
      )}
      {isLoading && committed !== null && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {data && (
        <>
          <div className="grid gap-3 md:grid-cols-5">
            <Card baslik="Toplam pencere" deger={String(data.ozet.toplam)} />
            <Card baslik="Tamamlanan" deger={String(data.ozet.tamamlandi)} tone="emerald" />
            <Card baslik="Kaçırılan" deger={String(data.ozet.kacirildi)} tone="red" />
            <Card baslik="Bekleyen" deger={String(data.ozet.bekliyor)} tone="amber" />
            <Card baslik="Tamamlanma oranı" deger={oran} />
          </div>

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium">Pencereler</h2>
              <button className={btnGhost} onClick={exportCsv} disabled={data.items.length === 0}>
                CSV indir
              </button>
            </div>
            <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 text-left text-slate-500">
                    <tr>
                      <th className="px-4 py-2.5 font-medium">Plan</th>
                      <th className="px-4 py-2.5 font-medium">Başlangıç</th>
                      <th className="px-4 py-2.5 font-medium">Bitiş</th>
                      <th className="px-4 py-2.5 font-medium">Durum</th>
                      <th className="px-4 py-2.5 font-medium">Checkpoint</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.map((w) => (
                      <tr key={w.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                        <td className="px-4 py-2.5">{w.plan_adi ?? "—"}</td>
                        <td className="px-4 py-2.5 text-slate-600">{formatDateTime(w.pencere_baslangic)}</td>
                        <td className="px-4 py-2.5 text-slate-600">{formatDateTime(w.pencere_bitis)}</td>
                        <td className="px-4 py-2.5">
                          <span
                            className={`rounded-full px-2 py-0.5 text-xs font-medium ${DURUM_STYLE[w.durum] ?? "bg-slate-100 text-slate-700"}`}
                          >
                            {w.durum}
                          </span>
                        </td>
                        <td className="px-4 py-2.5 text-slate-600 tabular-nums">
                          {w.okutulan_checkpoint_sayisi}/{w.beklenen_checkpoint_sayisi}
                        </td>
                      </tr>
                    ))}
                    {data.items.length === 0 && (
                      <tr>
                        <td colSpan={5}>
                          <EmptyState title="Pencere yok" description="Seçili filtrelerde tur penceresi bulunmuyor." />
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
            <Pager
              offset={offset}
              limit={LIMIT}
              total={data.meta.total}
              onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
              onNext={() => setOffset(offset + LIMIT)}
            />
          </section>
        </>
      )}
    </div>
  );
}

function Card({
  baslik,
  deger,
  tone,
}: {
  baslik: string;
  deger: string;
  tone?: "emerald" | "red" | "amber";
}) {
  const cls =
    tone === "red"
      ? "bg-red-50 text-red-700"
      : tone === "emerald"
        ? "bg-emerald-50 text-emerald-700"
        : tone === "amber"
          ? "bg-amber-50 text-amber-700"
          : "bg-slate-50 text-slate-800";
  return (
    <div className={`rounded-xl p-4 ${cls}`}>
      <div className="text-xs text-muted">{baslik}</div>
      <div className="text-xl font-semibold">{deger}</div>
    </div>
  );
}
