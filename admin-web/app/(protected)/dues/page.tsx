"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
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
  const toast = useToast();
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
      toast.success("Toplu tahakkuk oluşturuldu.");
    } catch (err) {
      setBErr(err instanceof Error ? err.message : "Tahakkuk oluşturulamadı.");
    } finally {
      setBBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title="Aidat" />

      {/* Toplu tahakkuk */}
      <motion.form {...panelMotion} onSubmit={bulk} className={`space-y-3 ${panelCls}`}>
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
      </motion.form>

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
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Daire</th>
                  <th className="px-4 py-2.5 font-medium">Dönem</th>
                  <th className="px-4 py-2.5 font-medium">Tutar</th>
                  <th className="px-4 py-2.5 font-medium">Son ödeme</th>
                </tr>
              </thead>
              <tbody>
                {(assessments?.items ?? []).map((a) => (
                  <tr key={a.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                    <td className="px-4 py-2.5 font-mono text-slate-600">{a.unit_id.slice(0, 8)}</td>
                    <td className="px-4 py-2.5">{a.donem}</td>
                    <td className="px-4 py-2.5 font-medium tabular-nums">{kurusToTL(a.tutar_kurus)}</td>
                    <td className="px-4 py-2.5 text-slate-600">{a.son_odeme_tarihi ?? "—"}</td>
                  </tr>
                ))}
                {assessments && assessments.items.length === 0 && (
                  <tr>
                    <td colSpan={4}>
                      <EmptyState title="Tahakkuk yok" description="Dönem filtresini değiştirin ya da yukarıdan toplu tahakkuk oluşturun." />
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
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
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Daire</th>
                  <th className="px-4 py-2.5 font-medium">Yöntem</th>
                  <th className="px-4 py-2.5 font-medium">Durum</th>
                  <th className="px-4 py-2.5 font-medium">Tutar</th>
                  <th className="px-4 py-2.5 font-medium">Zaman</th>
                </tr>
              </thead>
              <tbody>
                {(payments?.items ?? []).map((p) => (
                  <tr key={p.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                    <td className="px-4 py-2.5 font-mono text-slate-600">{p.unit_id.slice(0, 8)}</td>
                    <td className="px-4 py-2.5">{p.yontem}</td>
                    <td className="px-4 py-2.5">
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
                    <td className="px-4 py-2.5 font-medium tabular-nums">{kurusToTL(p.tutar_kurus)}</td>
                    <td className="px-4 py-2.5 text-slate-600">{formatDateTime(p.odeme_zamani)}</td>
                  </tr>
                ))}
                {payments && payments.items.length === 0 && (
                  <tr>
                    <td colSpan={5}>
                      <EmptyState title="Ödeme yok" description="Henüz kayıtlı ödeme bulunmuyor." />
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
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
