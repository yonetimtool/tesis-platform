"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, Field, PageHeader, inputCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import type { TransparencyBoard, TransparencyList } from "@/lib/types";

const AY_ADLARI = [
  "", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
  "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
];

function ayBaslik(ay: string): string {
  const [y, m] = ay.split("-");
  const i = Number(m);
  return i >= 1 && i <= 12 ? `${AY_ADLARI[i]} ${y}` : ay;
}

function tl(kurus: number): string {
  const neg = kurus < 0;
  const abs = Math.abs(kurus);
  const tam = Math.floor(abs / 100)
    .toLocaleString("tr-TR")
    .replace(/ /g, ".");
  const ond = String(abs % 100).padStart(2, "0");
  return `${neg ? "-" : ""}${tam},${ond} TL`;
}

export default function TransparencyPage() {
  const list = useSWR<TransparencyList>("/api/transparency", jsonFetcher);
  const [ay, setAy] = useState<string>("");

  const months = list.data?.items ?? [];
  useEffect(() => {
    const items = list.data?.items ?? [];
    if (!ay && items.length > 0) setAy(items[0].ay);
  }, [ay, list.data]);

  const board = useSWR<TransparencyBoard>(
    ay ? `/api/transparency/${ay}` : null,
    jsonFetcher,
  );
  const b = board.data;

  return (
    <div className="space-y-5">
      <PageHeader
        title="Şeffaflık Panosu"
        subtitle="Aylık anonim finansal özet (salt okuma). Yayın kontrolü mobil yönetici ekranındadır."
      />

      {list.error && <ErrorBox message="Aylar yüklenemedi." />}
      {list.isLoading && !list.data && (
        <p className="text-sm text-muted">Yükleniyor...</p>
      )}

      {list.data && months.length === 0 && (
        <EmptyState
          title="Veri yok"
          description="Bu tesiste henüz gelir/gider veya aidat kaydı yok."
        />
      )}

      {months.length > 0 && (
        <>
          <div className="w-64">
            <Field label="Dönem">
              <select
                className={inputCls}
                value={ay}
                onChange={(e) => setAy(e.target.value)}
              >
                {months.map((m) => (
                  <option key={m.ay} value={m.ay}>
                    {ayBaslik(m.ay)}
                    {m.yayinlandi ? "" : " • taslak"}
                  </option>
                ))}
              </select>
            </Field>
          </div>

          {board.error && <ErrorBox message="Özet yüklenemedi." />}
          {b && (
            <div className="grid gap-4 lg:grid-cols-2">
              {/* Özet */}
              <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-card">
                <div className="mb-3 flex items-center justify-between">
                  <h2 className="font-medium">{ayBaslik(b.ay)} — Özet</h2>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      b.yayinlandi
                        ? "bg-emerald-100 text-emerald-800"
                        : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {b.yayinlandi ? "yayında" : "taslak"}
                  </span>
                </div>
                <dl className="space-y-1.5 text-sm">
                  <Row k="Toplam gelir" v={tl(b.toplam_gelir_kurus)} cls="text-emerald-700" />
                  <Row k="Toplam gider" v={tl(b.toplam_gider_kurus)} cls="text-red-700" />
                  <div className="my-2 border-t border-slate-100" />
                  <Row
                    k="Net"
                    v={tl(b.net_kurus)}
                    cls={b.net_kurus >= 0 ? "text-emerald-700 font-semibold" : "text-red-700 font-semibold"}
                  />
                  {b.onceki_ay_net_kurus != null && (
                    <p className="pt-1 text-xs text-muted">
                      Önceki ay net: {tl(b.onceki_ay_net_kurus)}
                    </p>
                  )}
                </dl>
              </div>

              {/* Aidat */}
              <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-card">
                <h2 className="mb-3 font-medium">Aidat toplama</h2>
                {b.aidat.daire_orani_yuzde == null ? (
                  <p className="text-sm text-muted">Bu ay için tahakkuk yok.</p>
                ) : (
                  <>
                    <div className="mb-1 flex justify-between text-sm">
                      <span>
                        Ödeyen daire: {b.aidat.odeyen_daire}/{b.aidat.toplam_daire}
                      </span>
                      <span className="font-semibold">%{b.aidat.daire_orani_yuzde}</span>
                    </div>
                    <Bar value={b.aidat.daire_orani_yuzde} />
                    <p className="mt-2 text-xs text-muted">
                      Tahsilat: {tl(b.aidat.tahsilat_kurus)} / {tl(b.aidat.tahakkuk_kurus)}{" "}
                      (tutar: %{b.aidat.tutar_orani_yuzde ?? 0})
                    </p>
                  </>
                )}
                <p className="mt-3 text-sm">
                  Gecikmede <span className="font-semibold">{b.aidat.geciken_daire_sayisi}</span> daire
                </p>
              </div>

              {/* Gider dağılımı */}
              <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-card lg:col-span-2">
                <h2 className="mb-3 font-medium">Gider dağılımı</h2>
                {b.gider_dagilimi.length === 0 ? (
                  <p className="text-sm text-muted">Bu ay gider kaydı yok.</p>
                ) : (
                  <div className="space-y-3">
                    {b.gider_dagilimi.map((k) => (
                      <div key={k.ad}>
                        <div className="mb-1 flex justify-between text-sm">
                          <span>{k.ad}</span>
                          <span className="text-slate-500">
                            %{k.yuzde} · {tl(k.toplam_kurus)}
                          </span>
                        </div>
                        <Bar value={k.yuzde} indigo />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function Row({ k, v, cls }: { k: string; v: string; cls?: string }) {
  return (
    <div className="flex justify-between">
      <dt className="text-slate-600">{k}</dt>
      <dd className={cls}>{v}</dd>
    </div>
  );
}

function Bar({ value, indigo }: { value: number; indigo?: boolean }) {
  const pct = Math.max(0, Math.min(100, value));
  const color = indigo ? "bg-indigo-500" : pct >= 80 ? "bg-emerald-500" : "bg-amber-500";
  return (
    <div className="h-1.5 w-full overflow-hidden rounded bg-slate-100">
      <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
    </div>
  );
}
