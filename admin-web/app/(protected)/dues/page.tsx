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
import { useT } from "@/lib/i18n/kullan";
import type {
  DuesAssessmentList,
  DuesAssessmentResult,
  DuesPaymentList,
} from "@/lib/types";

const LIMIT = 20;

export default function DuesPage() {
  const t = useT();
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
  // HATA SESSIZ KALMAMALI: uc dustugunde sayfa "Tahakkuk yok" gosteriyordu —
  // kullanici "kayit yok" ile "sunucu dustu"yu ayirt edemiyordu (tur 42).
  const {
    data: assessments,
    error: aErr,
    isLoading: aYukleniyor,
    mutate: mutateA,
  } = useSWR<DuesAssessmentList>(
    `/api/dues/assessments?limit=${LIMIT}&offset=${aOffset}${aQs}`,
    jsonFetcher,
  );

  const [pOffset, setPOffset] = useState(0);
  const {
    data: payments,
    error: pErr,
    isLoading: pYukleniyor,
  } = useSWR<DuesPaymentList>(
    `/api/dues/payments?limit=${LIMIT}&offset=${pOffset}`,
    jsonFetcher,
  );

  async function bulk(e: React.FormEvent) {
    e.preventDefault();
    setBErr(null);
    setBRes(null);
    const k = tlToKurus(tl);
    if (k === null || k <= 0) {
      setBErr(t("aidatTutarGecersiz"));
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
      toast.success(t("aidatTopluOlusturuldu"));
    } catch (err) {
      setBErr(err instanceof Error ? err.message : t("aidatTopluOlusturulamadi"));
    } finally {
      setBBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("aidatBaslik")} />
      {(aErr || pErr) && <ErrorBox message={(aErr ?? pErr).message} />}
      {(aYukleniyor || pYukleniyor) && (
        <p role="status" className="text-sm text-muted">
          {t("ortakYukleniyor")}
        </p>
      )}

      {/* Toplu tahakkuk */}
      <motion.form {...panelMotion} onSubmit={bulk} className={`space-y-3 ${panelCls}`}>
        <h2 className="font-medium">{t("aidatTopluBaslik")}</h2>
        {/* DAR EKRAN: 4 sutun 360 dp'ye sigmiyor — Rusca etiketlerle sayfa
            yana kayiyordu (tur 25 surusu +23 px olctu). Dar ekranda 2,
            sm'den itibaren 4 sutun. */}
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Field label={t("ortakDonem")} hint={t("aidatDonemOrnek")}>
            <input
              className={inputCls}
              value={donem}
              onChange={(e) => setDonem(e.target.value)}
              placeholder="2026-07"
              required
            />
          </Field>
          <Field label={t("aidatTutarTl")}>
            <input
              className={inputCls}
              inputMode="decimal"
              value={tl}
              onChange={(e) => setTl(e.target.value)}
              placeholder="750,00"
              required
            />
          </Field>
          <Field label={t("aidatSonOdeme")}>
            <input type="date" className={inputCls} value={son} onChange={(e) => setSon(e.target.value)} />
          </Field>
          <Field label={t("ortakAciklamaOpsiyonel")}>
            <input className={inputCls} value={desc} onChange={(e) => setDesc(e.target.value)} />
          </Field>
        </div>
        <ErrorBox message={bErr} />
        {bRes && (
          <p className="text-sm text-emerald-700">
            {t("aidatTopluSonuc", { olusan: bRes.created, atlanan: bRes.atlanan })}
          </p>
        )}
        <button type="submit" className={btnPrimary} disabled={bBusy}>
          {bBusy ? t("aidatOlusturuluyor") : t("aidatTopluOlustur")}
        </button>
      </motion.form>

      {/* Tahakkuk listesi */}
      <section className="space-y-3">
        <div className="flex flex-wrap items-end justify-between gap-2">
          <h2 className="text-lg font-medium">{t("aidatTahakkuklar")}</h2>
          <div className="w-full sm:w-48">
            <Field label={t("aidatDonemFiltresi")}>
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
          <div className="odak-ic overflow-x-auto" tabIndex={0}>
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">{t("raporTabloDaire")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("ortakDonem")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("raporTabloTutar")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("aidatSonOdemeKisa")}</th>
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
                      <EmptyState title={t("aidatTahakkukYok")} description={t("aidatTahakkukYokAlt")} />
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
        <h2 className="text-lg font-medium">{t("aidatOdemeler")}</h2>
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
          <div className="odak-ic overflow-x-auto" tabIndex={0}>
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">{t("raporTabloDaire")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("aidatYontem")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("ortakDurum")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("raporTabloTutar")}</th>
                  <th className="px-4 py-2.5 font-medium">{t("raporTabloZaman")}</th>
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
                      <EmptyState title={t("aidatOdemeYok")} description={t("aidatOdemeYokAlt")} />
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
