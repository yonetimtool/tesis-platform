"use client";

import { useState } from "react";
import useSWR, { mutate } from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, Field, PageHeader, Pager, inputCls } from "@/components/form";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";

const LIMIT = 50;

type SupportTicket = {
  id: string;
  tenant_id: string;
  tenant_ad: string | null;
  acan_user_id: string;
  konu: string;
  aciklama: string;
  durum: "acik" | "cozuldu";
  admin_cevap: string | null;
  created_at: string;
};

type SupportList = {
  meta: { limit: number; offset: number; total: number };
  items: SupportTicket[];
};

// Destek kanali (WP1): tum tesislerin yonetici biletleri — filtre (durum +
// tenant), detayda yanit + cozuldu isareti. Backend RBAC admin'i zorlar.
export default function SupportPage() {
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [secili, setSecili] = useState<SupportTicket | null>(null);
  const [cevap, setCevap] = useState("");
  const [cozulduIsaretle, setCozulduIsaretle] = useState(true);
  const [gonderiliyor, setGonderiliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (durum) qs.set("durum", durum);
  if (tenantId) qs.set("tenant_id", tenantId);
  const url = `/api/support?${qs.toString()}`;
  const { data, error, isLoading } = useSWR<SupportList>(url, jsonFetcher);

  async function yanitla() {
    if (!secili) return;
    setGonderiliyor(true);
    setHata(null);
    try {
      const res = await fetch(`/api/support/${secili.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...(cevap.trim() ? { admin_cevap: cevap.trim() } : {}),
          ...(cozulduIsaretle ? { durum: "cozuldu" } : {}),
        }),
      });
      if (!res.ok) throw new Error(`Yanıt kaydedilemedi (${res.status})`);
      setSecili(null);
      setCevap("");
      await mutate(url);
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setGonderiliyor(false);
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Destek"
        subtitle="Tesis yöneticilerinden gelen platform destek talepleri — yanıtla ve çözüldü işaretle."
      />

      <div className="flex flex-wrap gap-3">
        <Field label="Durum">
          <select
            className={inputCls}
            value={durum}
            onChange={(e) => {
              setDurum(e.target.value);
              setOffset(0);
            }}
          >
            <option value="">Tümü</option>
            <option value="acik">Açık</option>
            <option value="cozuldu">Çözüldü</option>
          </select>
        </Field>
        <Field label="Tesis (tenant id)">
          <input
            className={inputCls}
            value={tenantId}
            placeholder="uuid — boş: tümü"
            onChange={(e) => {
              setTenantId(e.target.value.trim());
              setOffset(0);
            }}
          />
        </Field>
      </div>

      <ErrorBox message={error ? String(error) : null} />
      <ErrorBox message={hata} />

      {isLoading ? (
        <p className="text-sm text-slate-500">Yükleniyor…</p>
      ) : !data || data.items.length === 0 ? (
        <EmptyState
          title="Destek talebi yok"
          description="Seçili filtrelerde bilet bulunamadı."
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500 dark:border-slate-700">
                <th className="px-3 py-2">Tarih</th>
                <th className="px-3 py-2">Tesis</th>
                <th className="px-3 py-2">Konu</th>
                <th className="px-3 py-2">Durum</th>
                <th className="px-3 py-2">Yanıt</th>
                <th className="px-3 py-2" />
              </tr>
            </thead>
            <tbody>
              {data.items.map((t) => (
                <tr
                  key={t.id}
                  className="border-b border-slate-100 last:border-0 dark:border-slate-800"
                >
                  <td className="whitespace-nowrap px-3 py-2 text-slate-500">
                    {formatDateTime(t.created_at)}
                  </td>
                  <td className="px-3 py-2">{t.tenant_ad ?? t.tenant_id.slice(0, 8)}</td>
                  <td className="max-w-[28rem] px-3 py-2">
                    <div className="font-medium">{t.konu}</div>
                    <div className="truncate text-xs text-slate-500">{t.aciklama}</div>
                  </td>
                  <td className="px-3 py-2">
                    <span
                      className={
                        t.durum === "cozuldu"
                          ? "rounded-md bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300"
                          : "rounded-md bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"
                      }
                    >
                      {t.durum === "cozuldu" ? "Çözüldü" : "Açık"}
                    </span>
                  </td>
                  <td className="max-w-[16rem] truncate px-3 py-2 text-xs text-slate-500">
                    {t.admin_cevap ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-right">
                    <button
                      className="rounded-lg border border-slate-300 px-2 py-1 text-xs font-medium hover:bg-slate-50 dark:border-slate-600 dark:hover:bg-slate-800"
                      onClick={() => {
                        setSecili(t);
                        setCevap(t.admin_cevap ?? "");
                        setCozulduIsaretle(t.durum !== "cozuldu");
                      }}
                    >
                      Yanıtla
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {data ? (
        <Pager
          limit={LIMIT}
          offset={offset}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      ) : null}

      {secili ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-xl dark:bg-slate-900">
            <h2 className="text-base font-semibold">{secili.konu}</h2>
            <p className="mt-1 text-xs text-slate-500">
              {secili.tenant_ad ?? secili.tenant_id} · {formatDateTime(secili.created_at)}
            </p>
            <p className="mt-3 whitespace-pre-wrap rounded-lg bg-slate-50 p-3 text-sm dark:bg-slate-800">
              {secili.aciklama}
            </p>
            <Field label="Yanıt">
              <textarea
                className={`${inputCls} min-h-[6rem]`}
                value={cevap}
                onChange={(e) => setCevap(e.target.value)}
                maxLength={4000}
              />
            </Field>
            <label className="mt-2 flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={cozulduIsaretle}
                onChange={(e) => setCozulduIsaretle(e.target.checked)}
              />
              Çözüldü olarak işaretle
            </label>
            <div className="mt-4 flex justify-end gap-2">
              <button
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-600"
                onClick={() => setSecili(null)}
                disabled={gonderiliyor}
              >
                Vazgeç
              </button>
              <button
                className="rounded-lg bg-slate-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900"
                onClick={yanitla}
                disabled={gonderiliyor || (!cevap.trim() && !cozulduIsaretle)}
              >
                {gonderiliyor ? "Gönderiliyor…" : "Gönder"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
