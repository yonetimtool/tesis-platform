"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { kurusToTL, tlToKurus } from "@/lib/money";
import type {
  DuesAssessmentList,
  DuesAssessmentResult,
  DuesPaymentList,
} from "@/lib/types";

const LIMIT = 20;

export default function DuesPage() {
  // --- toplu tahakkuk ---
  const [donem, setDonem] = useState("");
  const [tl, setTl] = useState("");
  const [son, setSon] = useState("");
  const [desc, setDesc] = useState("");
  const [bErr, setBErr] = useState<string | null>(null);
  const [bRes, setBRes] = useState<{ created: number; atlanan: number } | null>(null);
  const [bBusy, setBBusy] = useState(false);

  // --- listeler ---
  const [aDonem, setADonem] = useState("");
  const [aOffset, setAOffset] = useState(0);
  const aQs = aDonem ? `&donem=${encodeURIComponent(aDonem)}` : "";
  const { data: assessments, mutate: mutateA } = useSWR<DuesAssessmentList>(
    `/api/dues/assessments?limit=${LIMIT}&offset=${aOffset}${aQs}`,
    jsonFetcher,
  );

  const [pOffset, setPOffset] = useState(0);
  const { data: payments } = useSWR<DuesPaymentList>(
    `/api/dues/payments?limit=${LIMIT}&offset=${pOffset}`,
    jsonFetcher,
  );

  async function bulk(e: React.FormEvent) {
    e.preventDefault();
    setBErr(null);
    setBRes(null);
    const k = tlToKurus(tl);
    if (k === null || k <= 0) {
      setBErr("Geçerli bir tutar girin (sıfırdan büyük).");
      return;
    }
    setBBusy(true);
    try {
      // unit_id/unit_ids YOK -> tum aktif daireler. Mevcut donemler atlanir.
      const res = await apiSend<DuesAssessmentResult>("/api/dues/assessments", "POST", {
        donem,
        tutar_kurus: k,
        son_odeme_tarihi: son || null,
        aciklama: desc || null,
      });
      setBRes({ created: res.created.length, atlanan: res.atlanan });
      mutateA();
    } catch (err) {
      setBErr(err instanceof Error ? err.message : "Tahakkuk oluşturulamadı.");
    } finally {
      setBBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Aidat</h1>

      {/* Toplu tahakkuk */}
      <form onSubmit={bulk} className="space-y-3 rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="font-medium">Toplu tahakkuk (tüm aktif daireler)</h2>
        <div className="grid grid-cols-4 gap-3">
          <Field label="Dönem" hint="Örnek: 2026-07">
            <input
              className={inputCls}
              value={donem}
              onChange={(e) => setDonem(e.target.value)}
              placeholder="2026-07"
              required
            />
          </Field>
          <Field label="Tutar (TL)">
            <input
              className={inputCls}
              inputMode="decimal"
              value={tl}
              onChange={(e) => setTl(e.target.value)}
              placeholder="750,00"
              required
            />
          </Field>
          <Field label="Son ödeme (opsiyonel)">
            <input type="date" className={inputCls} value={son} onChange={(e) => setSon(e.target.value)} />
          </Field>
          <Field label="Açıklama (opsiyonel)">
            <input className={inputCls} value={desc} onChange={(e) => setDesc(e.target.value)} />
          </Field>
        </div>
        <ErrorBox message={bErr} />
        {bRes && (
          <p className="text-sm text-emerald-700">
            {bRes.created} tahakkuk oluşturuldu · {bRes.atlanan} atlandı (zaten vardı).
          </p>
        )}
        <button type="submit" className={btnPrimary} disabled={bBusy}>
          {bBusy ? "Oluşturuluyor..." : "Toplu tahakkuk oluştur"}
        </button>
      </form>

      {/* Tahakkuk listesi */}
      <section className="space-y-3">
        <div className="flex items-end justify-between">
          <h2 className="text-lg font-medium">Tahakkuklar</h2>
          <div className="w-48">
            <Field label="Dönem filtresi">
              <input
                className={inputCls}
                value={aDonem}
                onChange={(e) => {
                  setADonem(e.target.value);
                  setAOffset(0);
                }}
                placeholder="2026-07"
              />
            </Field>
          </div>
        </div>
        <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-3 py-2 font-medium">Daire</th>
                <th className="px-3 py-2 font-medium">Dönem</th>
                <th className="px-3 py-2 font-medium">Tutar</th>
                <th className="px-3 py-2 font-medium">Son ödeme</th>
              </tr>
            </thead>
            <tbody>
              {(assessments?.items ?? []).map((a) => (
                <tr key={a.id} className="border-t border-slate-100">
                  <td className="px-3 py-2 font-mono text-slate-600">{a.unit_id.slice(0, 8)}</td>
                  <td className="px-3 py-2">{a.donem}</td>
                  <td className="px-3 py-2 font-medium">{kurusToTL(a.tutar_kurus)}</td>
                  <td className="px-3 py-2 text-slate-600">{a.son_odeme_tarihi ?? "—"}</td>
                </tr>
              ))}
              {assessments && assessments.items.length === 0 && (
                <tr>
                  <td className="px-3 py-6 text-center text-muted" colSpan={4}>
                    Tahakkuk yok.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {assessments && (
          <Pager
            offset={aOffset}
            limit={LIMIT}
            total={assessments.meta.total}
            onPrev={() => setAOffset(Math.max(0, aOffset - LIMIT))}
            onNext={() => setAOffset(aOffset + LIMIT)}
          />
        )}
      </section>

      {/* Odeme listesi */}
      <section className="space-y-3">
        <h2 className="text-lg font-medium">Ödemeler</h2>
        <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-3 py-2 font-medium">Daire</th>
                <th className="px-3 py-2 font-medium">Yöntem</th>
                <th className="px-3 py-2 font-medium">Durum</th>
                <th className="px-3 py-2 font-medium">Tutar</th>
                <th className="px-3 py-2 font-medium">Zaman</th>
              </tr>
            </thead>
            <tbody>
              {(payments?.items ?? []).map((p) => (
                <tr key={p.id} className="border-t border-slate-100">
                  <td className="px-3 py-2 font-mono text-slate-600">{p.unit_id.slice(0, 8)}</td>
                  <td className="px-3 py-2">{p.yontem}</td>
                  <td className="px-3 py-2">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        p.durum === "basarili"
                          ? "bg-emerald-100 text-emerald-800"
                          : p.durum === "bekliyor"
                            ? "bg-amber-100 text-amber-800"
                            : "bg-slate-100 text-slate-600"
                      }`}
                    >
                      {p.durum}
                    </span>
                  </td>
                  <td className="px-3 py-2 font-medium">{kurusToTL(p.tutar_kurus)}</td>
                  <td className="px-3 py-2 text-slate-600">{formatDateTime(p.odeme_zamani)}</td>
                </tr>
              ))}
              {payments && payments.items.length === 0 && (
                <tr>
                  <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                    Ödeme yok.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {payments && (
          <Pager
            offset={pOffset}
            limit={LIMIT}
            total={payments.meta.total}
            onPrev={() => setPOffset(Math.max(0, pOffset - LIMIT))}
            onNext={() => setPOffset(pOffset + LIMIT)}
          />
        )}
      </section>
    </div>
  );
}
