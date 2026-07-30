"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion } from "@/components/form";
import { ReportsTabs } from "@/components/ReportsTabs";
import { fetchAllItems } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type {
  TaskCategoryList,
  TaskCompletionHistoryResponse,
  TaskCompletionRow,
  UserListResponse,
} from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";


const LIMIT = 20;
// GOREV TIPI = DINAMIK KATEGORI. Sabit dort tip (temizlik/kontrol/ilaclama/
// peyzaj) backend'den kaldirilmisti; panel eski alanlari okumaya devam
// ediyordu ve rapor ozet kartlari ekrana "undefined" yaziyordu (tur 41).
// Kategori adlari SUNUCU VERISIDIR — cevrilmez, oldugu gibi gosterilir.
const KART_TONLARI = ["teal", "blue", "violet", "emerald"] as const;

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
  const t = useT();
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [tamamlayan, setTamamlayan] = useState("");
  const [committed, setCommitted] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  const { data: users } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Suzgec KATEGORI uzerinden (sunucu `kategori_id` bekler). Eskiden sabit
  // `tip` degeri gonderiliyordu — sunucu o parametreyi hic okumuyordu, yani
  // suzgec SESSIZCE ETKISIZDI (tur 41).
  const { data: kategoriler } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  const [kategoriId, setKategoriId] = useState("");
  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? id.slice(0, 8);
  }

  function buildFilters(): string {
    const qs = new URLSearchParams();
    const b = toIso(bas);
    if (b) qs.set("baslangic", b);
    const e = toIso(bit);
    if (e) qs.set("bitis", e);
    if (kategoriId) qs.set("kategori_id", kategoriId);
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
      ["Gorev", "Tip", "Tamamlayan", "Zaman", "Foto", "NFC", t("raporNot")],
    ];
    for (const c of items) {
      rows.push([
        c.task_adi ?? "",
        c.kategori_ad,
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
      <PageHeader title={t("raporGorevGecmisiBaslik")} />

      <motion.form {...panelMotion} onSubmit={submit} className={`flex flex-wrap items-end gap-3 ${panelCls}`}>
        <div className="w-full sm:w-52">
          <Field label={t("ortakBaslangic")} hint={t("ortakYerelSaatOpsiyonel")}>
            <input type="datetime-local" className={inputCls} value={bas} onChange={(e) => setBas(e.target.value)} />
          </Field>
        </div>
        <div className="w-full sm:w-52">
          <Field label={t("ortakBitis")} hint={t("ortakYerelSaatOpsiyonel")}>
            <input type="datetime-local" className={inputCls} value={bit} onChange={(e) => setBit(e.target.value)} />
          </Field>
        </div>
        <div className="w-full sm:w-52">
          <Field label={t("gorevKategoriAlan")}>
            <select
              className={inputCls}
              value={kategoriId}
              onChange={(e) => setKategoriId(e.target.value)}
            >
              <option value="">{t("ortakTumu")}</option>
              {(kategoriler?.items ?? []).map((k) => (
                <option key={k.id} value={k.id}>
                  {k.ad}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-full sm:w-52">
          <Field label={t("raporTamamlayanOpsiyonel")}>
            <select className={inputCls} value={tamamlayan} onChange={(e) => setTamamlayan(e.target.value)}>
              <option value="">{t("ortakTumu")}</option>
              {(users?.items ?? []).map((u) => (
                <option key={u.id} value={u.id}>
                  {u.ad}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <button type="submit" className={btnPrimary}>
          {t("raporGetir")}
        </button>
      </motion.form>

      {error && <ErrorBox message={error.message} />}
      {committed === null && (
        <p className="text-sm text-muted">{t("raporFiltreSecin")}</p>
      )}
      {isLoading && committed !== null && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {data && (
        <>
          <div className="grid gap-3 md:grid-cols-5">
            <Card baslik={t("raporToplamTamamlama")} deger={String(data.ozet.toplam)} />
            {data.ozet.kalemler.map((k, i) => (
              <Card
                key={k.kategori_ad}
                baslik={k.kategori_ad}
                deger={String(k.sayi)}
                tone={KART_TONLARI[i % KART_TONLARI.length]}
              />
            ))}
          </div>

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium">{t("raporTamamlamalar")}</h2>
              <button className={btnGhost} onClick={exportCsv} disabled={data.items.length === 0}>
                {t("raporCsvIndir")}
              </button>
            </div>
            <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
              <div className="overflow-x-auto" tabIndex={0}>
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 text-left text-slate-500">
                    <tr>
                      <th className="px-4 py-2.5 font-medium">{t("raporGorev")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporTabloTip")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporTabloTamamlayan")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporTabloZaman")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporTabloFoto")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporTabloNfc")}</th>
                      <th className="px-4 py-2.5 font-medium">{t("raporNot")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.map((c) => (
                      <tr key={c.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                        <td className="px-4 py-2.5">{c.task_adi ?? "—"}</td>
                        <td className="px-4 py-2.5">
                          <span
                            className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700"
                          >
                            {c.kategori_ad}
                          </span>
                        </td>
                        <td className="px-4 py-2.5">{userName(c.tamamlayan_user_id)}</td>
                        <td className="px-4 py-2.5 text-slate-600">{formatDateTime(c.tamamlanma_zamani)}</td>
                        <td className="px-4 py-2.5">
                          {c.foto_var ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">{t("raporVar")}</span>
                          ) : (
                            <span className="text-muted">{t("raporYok")}</span>
                          )}
                        </td>
                        <td className="px-4 py-2.5">
                          {c.nfc_dogrulandi ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">✓</span>
                          ) : (
                            <span className="text-muted">—</span>
                          )}
                        </td>
                        <td className="px-4 py-2.5 text-slate-600">{c.notlar ?? "—"}</td>
                      </tr>
                    ))}
                    {data.items.length === 0 && (
                      <tr>
                        <td colSpan={7}>
                          <EmptyState title={t("raporTamamlamaYok")} description={t("raporSonucYok")} />
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
      <div className="text-xs text-slate-600">{baslik}</div>
      <div className="text-xl font-semibold">{deger}</div>
    </div>
  );
}
