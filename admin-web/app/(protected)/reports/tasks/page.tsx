"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { ReportsTabs } from "@/components/ReportsTabs";
import { fetchAllItems } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { TaskCompletionHistoryResponse, TaskCompletionRow, UserListResponse } from "@/lib/types";

const LIMIT = 20;
const TIPLER = [
  { value: "temizlik", label: "Temizlik" },
  { value: "kontrol", label: "Kontrol" },
  { value: "ilaclama", label: "İlaçlama" },
  { value: "peyzaj", label: "Peyzaj" },
];
const TIP_STYLE: Record<string, string> = {
  temizlik: "bg-teal-100 text-teal-800",
  kontrol: "bg-blue-100 text-blue-800",
  ilaclama: "bg-violet-100 text-violet-800",
  peyzaj: "bg-emerald-100 text-emerald-800",
};
function tipLabel(v: string): string {
  return TIPLER.find((t) => t.value === v)?.label ?? v;
}

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

export default function TaskReportPage() {
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [tip, setTip] = useState("");
  const [tamamlayan, setTamamlayan] = useState("");
  const [committed, setCommitted] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  const { data: users } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? id.slice(0, 8);
  }

  function buildFilters(): string {
    const qs = new URLSearchParams();
    const b = toIso(bas);
    if (b) qs.set("baslangic", b);
    const e = toIso(bit);
    if (e) qs.set("bitis", e);
    if (tip) qs.set("tip", tip);
    if (tamamlayan) qs.set("tamamlayan_user_id", tamamlayan);
    return qs.toString();
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setCommitted(buildFilters());
    setOffset(0);
  }

  const key =
    committed !== null
      ? `/api/task-completions?${[committed, `limit=${LIMIT}`, `offset=${offset}`]
          .filter(Boolean)
          .join("&")}`
      : null;
  const { data, error, isLoading } = useSWR<TaskCompletionHistoryResponse>(key, jsonFetcher);

  async function exportCsv() {
    if (committed === null) return;
    const items = await fetchAllItems<TaskCompletionRow>(`/api/task-completions?${committed}`);
    const rows: string[][] = [
      ["Gorev", "Tip", "Tamamlayan", "Zaman", "Foto", "NFC", "Not"],
    ];
    for (const c of items) {
      rows.push([
        c.task_adi ?? "",
        c.tip,
        userName(c.tamamlayan_user_id),
        c.tamamlanma_zamani,
        c.foto_var ? "var" : "yok",
        c.nfc_dogrulandi ? "evet" : "hayir",
        c.notlar ?? "",
      ]);
    }
    csvDownload("gorev-gecmisi.csv", rows);
  }

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <h1 className="text-2xl font-semibold">Görev Geçmişi Raporu</h1>

      <form onSubmit={submit} className="flex flex-wrap items-end gap-3 rounded-xl border border-slate-200 bg-white p-5">
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
          <Field label="Tip">
            <select className={inputCls} value={tip} onChange={(e) => setTip(e.target.value)}>
              <option value="">Tümü</option>
              {TIPLER.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-52">
          <Field label="Tamamlayan (opsiyonel)">
            <select className={inputCls} value={tamamlayan} onChange={(e) => setTamamlayan(e.target.value)}>
              <option value="">Tümü</option>
              {(users?.items ?? []).map((u) => (
                <option key={u.id} value={u.id}>
                  {u.ad}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <button type="submit" className={btnPrimary}>
          Raporu getir
        </button>
      </form>

      {error && <ErrorBox message={error.message} />}
      {committed === null && (
        <p className="text-sm text-muted">Filtre seçip Raporu getir butonuna basın.</p>
      )}
      {isLoading && committed !== null && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {data && (
        <>
          <div className="grid gap-3 md:grid-cols-5">
            <Card baslik="Toplam tamamlama" deger={String(data.ozet.toplam)} />
            <Card baslik="Temizlik" deger={String(data.ozet.temizlik)} tone="teal" />
            <Card baslik="Kontrol" deger={String(data.ozet.kontrol)} tone="blue" />
            <Card baslik="İlaçlama" deger={String(data.ozet.ilaclama)} tone="violet" />
            <Card baslik="Peyzaj" deger={String(data.ozet.peyzaj)} tone="emerald" />
          </div>

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium">Tamamlamalar</h2>
              <button className={btnGhost} onClick={exportCsv} disabled={data.items.length === 0}>
                CSV indir
              </button>
            </div>
            <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 text-left text-slate-500">
                  <tr>
                    <th className="px-3 py-2 font-medium">Görev</th>
                    <th className="px-3 py-2 font-medium">Tip</th>
                    <th className="px-3 py-2 font-medium">Tamamlayan</th>
                    <th className="px-3 py-2 font-medium">Zaman</th>
                    <th className="px-3 py-2 font-medium">Foto</th>
                    <th className="px-3 py-2 font-medium">NFC</th>
                    <th className="px-3 py-2 font-medium">Not</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((c) => (
                    <tr key={c.id} className="border-t border-slate-100">
                      <td className="px-3 py-2">{c.task_adi ?? "—"}</td>
                      <td className="px-3 py-2">
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs font-medium ${TIP_STYLE[c.tip] ?? "bg-slate-100 text-slate-700"}`}
                        >
                          {tipLabel(c.tip)}
                        </span>
                      </td>
                      <td className="px-3 py-2">{userName(c.tamamlayan_user_id)}</td>
                      <td className="px-3 py-2 text-slate-600">{formatDateTime(c.tamamlanma_zamani)}</td>
                      <td className="px-3 py-2">
                        {c.foto_var ? (
                          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">var</span>
                        ) : (
                          <span className="text-muted">yok</span>
                        )}
                      </td>
                      <td className="px-3 py-2">
                        {c.nfc_dogrulandi ? (
                          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">✓</span>
                        ) : (
                          <span className="text-muted">—</span>
                        )}
                      </td>
                      <td className="px-3 py-2 text-slate-600">{c.notlar ?? "—"}</td>
                    </tr>
                  ))}
                  {data.items.length === 0 && (
                    <tr>
                      <td className="px-3 py-6 text-center text-muted" colSpan={7}>
                        Tamamlama yok.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
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
  tone?: "teal" | "blue" | "violet" | "emerald";
}) {
  const cls =
    tone === "teal"
      ? "bg-teal-50 text-teal-700"
      : tone === "blue"
        ? "bg-blue-50 text-blue-700"
        : tone === "violet"
          ? "bg-violet-50 text-violet-700"
          : tone === "emerald"
            ? "bg-emerald-50 text-emerald-700"
            : "bg-slate-50 text-slate-800";
  return (
    <div className={`rounded-xl p-4 ${cls}`}>
      <div className="text-xs text-muted">{baslik}</div>
      <div className="text-xl font-semibold">{deger}</div>
    </div>
  );
}
