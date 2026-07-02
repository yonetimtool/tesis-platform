"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { EmergencyAlert, EmergencyList, UserListResponse } from "@/lib/types";

const LIMIT = 20;

export default function EmergencyPage() {
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (durum) qs.set("durum", durum);
  const { data, error, isLoading, mutate } = useSWR<EmergencyList>(
    `/api/emergency?${qs.toString()}`,
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );
  const { data: users } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  function userName(id?: string | null): string {
    if (!id) return "—";
    return users?.items.find((u) => u.id === id)?.ad ?? id.slice(0, 8);
  }

  // Acik alarmlar her zaman en ustte (sonra sunucu sirasi: zaman desc).
  const sorted = [...(data?.items ?? [])].sort((a, b) => {
    if (a.durum !== b.durum) return a.durum === "acik" ? -1 : 1;
    return 0;
  });
  const acikSayi = sorted.filter((a) => a.durum === "acik").length;

  async function resolve(a: EmergencyAlert) {
    const note = window.prompt("Cozum notu (opsiyonel):", a.notlar ?? "");
    if (note === null) return; // iptal
    try {
      await apiSend(`/api/emergency/${a.id}`, "PATCH", { notlar: note || null });
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Guncellenemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">
          Acil Durum
          {acikSayi > 0 && (
            <span className="ml-2 rounded-full bg-red-600 px-2 py-0.5 text-sm font-medium text-white">
              {acikSayi} acik
            </span>
          )}
        </h1>
        <div className="w-44">
          <Field label="Durum">
            <select
              className={inputCls}
              value={durum}
              onChange={(e) => {
                setDurum(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tumu</option>
              <option value="acik">Acik</option>
              <option value="cozuldu">Cozuldu</option>
            </select>
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yukleniyor...</p>}

      <ul className="space-y-3">
        {sorted.map((a) => {
          const acik = a.durum === "acik";
          return (
            <li
              key={a.id}
              className={`rounded-xl border p-4 ${
                acik ? "border-red-300 bg-red-50" : "border-slate-200 bg-white"
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        acik ? "bg-red-600 text-white" : "bg-emerald-100 text-emerald-800"
                      }`}
                    >
                      {acik ? "ACIK" : "cozuldu"}
                    </span>
                    <span className="text-sm font-medium">{userName(a.tetikleyen_user_id)}</span>
                    <span className="text-xs text-muted">{formatDateTime(a.tetiklenme_zamani)}</span>
                  </div>
                  {a.notlar && <p className="text-sm text-slate-800">{a.notlar}</p>}
                  {a.gps_lat != null && a.gps_lng != null && (
                    <a
                      className="text-xs text-blue-700 underline"
                      href={`https://www.google.com/maps?q=${a.gps_lat},${a.gps_lng}`}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Konum: {a.gps_lat}, {a.gps_lng}
                    </a>
                  )}
                  {!acik && a.cozen_user_id && (
                    <p className="text-xs text-muted">
                      Cozen: {userName(a.cozen_user_id)}
                      {a.cozulme_zamani ? ` · ${formatDateTime(a.cozulme_zamani)}` : ""}
                    </p>
                  )}
                </div>
                {acik && (
                  <button className={btnPrimary} onClick={() => resolve(a)}>
                    Cozuldu isaretle
                  </button>
                )}
              </div>
            </li>
          );
        })}
        {data && sorted.length === 0 && (
          <li className="rounded-xl border border-slate-200 bg-white px-3 py-6 text-center text-muted">
            Acil durum kaydi yok.
          </li>
        )}
      </ul>

      {data && (
        <Pager
          offset={offset}
          limit={LIMIT}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      )}
    </div>
  );
}
