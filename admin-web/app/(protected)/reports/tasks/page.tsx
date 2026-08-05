"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion,
  EksikVeriUyarisi,
} from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { ReportsTabs } from "@/components/ReportsTabs";
import { kisaKimlik } from "@/lib/kimlik";
import { fetchAllPaged } from "@/lib/client";
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
  /** (P65) Cekim ust sinira takildi mi — rapor EKSIKTIR. */
  const [kesildi, setKesildi] = useState(false);
  const [offset, setOffset] = useState(0);

  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Suzgec KATEGORI uzerinden (sunucu `kategori_id` bekler). Eskiden sabit
  // `tip` degeri gonderiliyordu — sunucu o parametreyi hic okumuyordu, yani
  // suzgec SESSIZCE ETKISIZDI (tur 41).
  const { data: kategoriler, error: kategorilerErr } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  const [kategoriId, setKategoriId] = useState("");
  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
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
    const cekim = await fetchAllPaged<TaskCompletionRow>(
      `/api/task-completions?${committed}`,
    );
    setKesildi(cekim.kesildi);
    const items = cekim.items;
    const rows: string[][] = [
      ["Gorev", "Tip", "Tamamlayan", "Zaman", "Foto", "NFC", t("raporNot")],
    ];
    for (const c of items) {
      rows.push([
        c.task_adi ?? "",
        c.kategori_ad,
        userName(c.tamamlayan_user_id),
        c.tamamlanma_zamani,
        c.foto_var ? t("raporVar") : t("raporYok"),
        c.nfc_dogrulandi ? t("ortakEvet") : t("ortakHayir"),
        c.notlar ?? "",
      ]);
    }
    csvDownload("gorev-gecmisi.csv", rows);
  }

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <PageHeader title={t("raporGorevGecmisiBaslik")} />

      <EksikVeriUyarisi
        mesaj={usersErr || kategorilerErr ? t("ortakSecenekYuklenemedi") : null}
      />

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

      {kesildi && (

        <p className="text-xs text-amber-700">{t("raporKesildi")}</p>

      )}
      {committed === null && (
        <p className="text-sm text-metin-muted">{t("raporFiltreSecin")}</p>
      )}
      {isLoading && committed !== null && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

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
            <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
              <div className="odak-ic overflow-x-auto" tabIndex={0}>
                <Tablo>
                  <TabloBasligi>
                      <Th>{t("raporGorev")}</Th>
                      <Th>{t("raporTabloTip")}</Th>
                      <Th>{t("raporTabloTamamlayan")}</Th>
                      <Th>{t("raporTabloZaman")}</Th>
                      <Th>{t("raporTabloFoto")}</Th>
                      <Th>{t("raporTabloNfc")}</Th>
                      <Th>{t("raporNot")}</Th>
                    </TabloBasligi>
                  <tbody>
                    {data.items.map((c) => (
                      <Tr key={c.id}>
                        <Td>{c.task_adi ?? "—"}</Td>
                        <Td>
                          <span
                            className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-metin-body"
                          >
                            {c.kategori_ad}
                          </span>
                        </Td>
                        <Td>{userName(c.tamamlayan_user_id)}</Td>
                        <Td className="text-metin-body">{formatDateTime(c.tamamlanma_zamani)}</Td>
                        <Td>
                          {c.foto_var ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">{t("raporVar")}</span>
                          ) : (
                            <span className="text-metin-muted">{t("raporYok")}</span>
                          )}
                        </Td>
                        <Td>
                          {c.nfc_dogrulandi ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">✓</span>
                          ) : (
                            <span className="text-metin-muted">—</span>
                          )}
                        </Td>
                        <Td className="text-metin-body">{c.notlar ?? "—"}</Td>
                      </Tr>
                    ))}
                    {data.items.length === 0 && (
                      <tr>
                        <Td colSpan={7}>
                          <EmptyState title={t("raporTamamlamaYok")} description={t("raporSonucYok")} />
                        </Td>
                      </tr>
                    )}
                  </tbody>
                </Tablo>
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
            : "bg-yuzey-bg text-slate-800";
  return (
    <div className={`rounded-xl p-4 ${cls}`}>
      <div className="text-xs text-metin-body">{baslik}</div>
      <div className="text-xl font-semibold">{deger}</div>
    </div>
  );
}
