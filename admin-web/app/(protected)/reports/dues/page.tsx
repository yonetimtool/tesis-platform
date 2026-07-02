"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { ReportsTabs } from "@/components/ReportsTabs";
import { fetchAllItems } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { kurusToTL } from "@/lib/money";
import type { DuesAssessment, DuesPayment, UnitList } from "@/lib/types";

interface BorcRow {
  unit_id: string;
  no: string;
  tahakkuk: number; // kurus
  odenen: number; // kurus
  kalan: number; // kurus
  son_odeme?: string | null;
}
interface OdemeRow {
  id: string;
  no: string;
  tutar: number; // kurus
  yontem: string;
  zaman: string;
}
interface Report {
  donem: string;
  toplamTahakkuk: number;
  toplamTahsilat: number;
  bakiye: number;
  oranYuzde: number; // tam sayi %
  daireTahakkuk: number;
  daireTamOdeyen: number;
  daireBorclu: number;
  borclular: BorcRow[];
  odemeler: OdemeRow[];
  serbestBasariliSayi: number; // doneme atfedilemeyen basarili odeme sayisi
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

export default function DuesReportPage() {
  const [donem, setDonem] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [report, setReport] = useState<Report | null>(null);

  // Daire no haritasi (ilk 200; daha fazlasi varsa not dusulur).
  const { data: units } = useSWR<UnitList>("/api/units?limit=200&offset=0", jsonFetcher);
  const unitTruncated = Boolean(units && units.meta.total > units.items.length);
  function unitNo(id: string): string {
    return units?.items.find((u) => u.id === id)?.no ?? id.slice(0, 8);
  }

  async function run(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setReport(null);
    if (!donem.trim()) {
      setErr("Lutfen bir donem girin (orn. 2026-06).");
      return;
    }
    setBusy(true);
    try {
      const [assessments, payments] = await Promise.all([
        fetchAllItems<DuesAssessment>(`/api/dues/assessments?donem=${encodeURIComponent(donem.trim())}`),
        fetchAllItems<DuesPayment>("/api/dues/payments"),
      ]);

      // Donem tahakkuklari (kurus, tam sayi).
      const tahakkukByUnit = new Map<string, number>();
      const sonOdemeByUnit = new Map<string, string | null>();
      const periodAssessmentIds = new Set<string>();
      for (const a of assessments) {
        tahakkukByUnit.set(a.unit_id, (tahakkukByUnit.get(a.unit_id) ?? 0) + a.tutar_kurus);
        sonOdemeByUnit.set(a.unit_id, a.son_odeme_tarihi ?? null);
        periodAssessmentIds.add(a.id);
      }

      // Basarili odemeler: yalniz bu donemin tahakkuklarina BAGLI olanlar.
      const odenenByUnit = new Map<string, number>();
      const odemeler: OdemeRow[] = [];
      let serbestBasariliSayi = 0;
      for (const p of payments) {
        if (p.durum !== "basarili") continue;
        if (p.assessment_id && periodAssessmentIds.has(p.assessment_id)) {
          odenenByUnit.set(p.unit_id, (odenenByUnit.get(p.unit_id) ?? 0) + p.tutar_kurus);
          odemeler.push({
            id: p.id,
            no: unitNo(p.unit_id),
            tutar: p.tutar_kurus,
            yontem: p.yontem,
            zaman: p.odeme_zamani,
          });
        } else if (!p.assessment_id) {
          serbestBasariliSayi += 1;
        }
      }

      // Toplamlar (kurus tam sayi).
      let toplamTahakkuk = 0;
      for (const v of tahakkukByUnit.values()) toplamTahakkuk += v;
      let toplamTahsilat = 0;
      for (const v of odenenByUnit.values()) toplamTahsilat += v;
      const bakiye = toplamTahakkuk - toplamTahsilat;
      const oranYuzde = toplamTahakkuk > 0 ? Math.floor((toplamTahsilat * 100) / toplamTahakkuk) : 0;

      const borclular: BorcRow[] = [];
      let daireTamOdeyen = 0;
      for (const [unit_id, tahakkuk] of tahakkukByUnit.entries()) {
        const odenen = odenenByUnit.get(unit_id) ?? 0;
        const kalan = tahakkuk - odenen;
        if (kalan <= 0) daireTamOdeyen += 1;
        else borclular.push({ unit_id, no: unitNo(unit_id), tahakkuk, odenen, kalan, son_odeme: sonOdemeByUnit.get(unit_id) ?? null });
      }
      borclular.sort((a, b) => b.kalan - a.kalan);
      odemeler.sort((a, b) => (a.zaman < b.zaman ? 1 : -1));

      setReport({
        donem: donem.trim(),
        toplamTahakkuk,
        toplamTahsilat,
        bakiye,
        oranYuzde,
        daireTahakkuk: tahakkukByUnit.size,
        daireTamOdeyen,
        daireBorclu: borclular.length,
        borclular,
        odemeler,
        serbestBasariliSayi,
      });
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : "Rapor olusturulamadi.");
    } finally {
      setBusy(false);
    }
  }

  function exportBorclular() {
    if (!report) return;
    const rows: string[][] = [["Daire", "Tahakkuk_TL", "Odenen_TL", "Kalan_TL", "Son_odeme"]];
    for (const b of report.borclular) {
      rows.push([
        b.no,
        kurusToTL(b.tahakkuk).replace(" ₺", ""),
        kurusToTL(b.odenen).replace(" ₺", ""),
        kurusToTL(b.kalan).replace(" ₺", ""),
        b.son_odeme ?? "",
      ]);
    }
    csvDownload(`borclu-daireler-${report.donem}.csv`, rows);
  }

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <h1 className="text-2xl font-semibold">Aidat Tahsilat Raporu</h1>

      <form onSubmit={run} className="flex items-end gap-3 rounded-xl border border-slate-200 bg-white p-5">
        <div className="w-56">
          <Field label="Donem" hint="Ornek: 2026-06">
            <input
              className={inputCls}
              value={donem}
              onChange={(e) => setDonem(e.target.value)}
              placeholder="2026-06"
            />
          </Field>
        </div>
        <button type="submit" className={btnPrimary} disabled={busy}>
          {busy ? "Hesaplaniyor..." : "Raporu getir"}
        </button>
      </form>

      {err && <ErrorBox message={err} />}
      {unitTruncated && (
        <p className="text-xs text-amber-700">
          Not: 200 daireden fazla var; daire adlari bir kismi icin kisaltilmis ID gosterebilir.
        </p>
      )}

      {report && (
        <>
          {/* Ozet kartlari */}
          <div className="grid gap-3 md:grid-cols-4">
            <Card baslik="Toplam tahakkuk" deger={kurusToTL(report.toplamTahakkuk)} />
            <Card baslik="Toplam tahsilat" deger={kurusToTL(report.toplamTahsilat)} tone="emerald" />
            <Card baslik="Bakiye (borc)" deger={kurusToTL(report.bakiye)} tone={report.bakiye > 0 ? "red" : "emerald"} />
            <Card baslik="Tahsilat orani" deger={`% ${report.oranYuzde}`} />
          </div>
          <div className="grid gap-3 md:grid-cols-3">
            <Card baslik="Tahakkuk edilen daire" deger={String(report.daireTahakkuk)} />
            <Card baslik="Tam odeyen daire" deger={String(report.daireTamOdeyen)} tone="emerald" />
            <Card baslik="Borclu daire" deger={String(report.daireBorclu)} tone={report.daireBorclu > 0 ? "red" : "emerald"} />
          </div>

          {report.serbestBasariliSayi > 0 && (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
              Not: {report.serbestBasariliSayi} basarili odeme bir tahakkuga bagli degil
              (serbest); donem tahsilatina dahil EDILEMEDI. (Backend odemeye donem alani
              eklerse bu kapanir.)
            </p>
          )}

          {/* Borclu daireler */}
          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium">Borclu daireler</h2>
              <button className={btnGhost} onClick={exportBorclular} disabled={report.borclular.length === 0}>
                CSV indir
              </button>
            </div>
            <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 text-left text-slate-500">
                  <tr>
                    <th className="px-3 py-2 font-medium">Daire</th>
                    <th className="px-3 py-2 font-medium">Tahakkuk</th>
                    <th className="px-3 py-2 font-medium">Odenen</th>
                    <th className="px-3 py-2 font-medium">Kalan borc</th>
                    <th className="px-3 py-2 font-medium">Son odeme</th>
                  </tr>
                </thead>
                <tbody>
                  {report.borclular.map((b) => (
                    <tr key={b.unit_id} className="border-t border-slate-100">
                      <td className="px-3 py-2">{b.no}</td>
                      <td className="px-3 py-2 text-slate-600">{kurusToTL(b.tahakkuk)}</td>
                      <td className="px-3 py-2 text-slate-600">{kurusToTL(b.odenen)}</td>
                      <td className="px-3 py-2 font-medium text-red-700">{kurusToTL(b.kalan)}</td>
                      <td className="px-3 py-2 text-slate-600">{b.son_odeme ?? "—"}</td>
                    </tr>
                  ))}
                  {report.borclular.length === 0 && (
                    <tr>
                      <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                        Borclu daire yok.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>

          {/* Odemeler */}
          <section className="space-y-2">
            <h2 className="text-lg font-medium">Donem tahsilatlari (basarili)</h2>
            <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 text-left text-slate-500">
                  <tr>
                    <th className="px-3 py-2 font-medium">Daire</th>
                    <th className="px-3 py-2 font-medium">Tutar</th>
                    <th className="px-3 py-2 font-medium">Yontem</th>
                    <th className="px-3 py-2 font-medium">Zaman</th>
                  </tr>
                </thead>
                <tbody>
                  {report.odemeler.map((o) => (
                    <tr key={o.id} className="border-t border-slate-100">
                      <td className="px-3 py-2">{o.no}</td>
                      <td className="px-3 py-2 font-medium">{kurusToTL(o.tutar)}</td>
                      <td className="px-3 py-2 text-slate-600">{o.yontem}</td>
                      <td className="px-3 py-2 text-slate-600">{formatDateTime(o.zaman)}</td>
                    </tr>
                  ))}
                  {report.odemeler.length === 0 && (
                    <tr>
                      <td className="px-3 py-6 text-center text-muted" colSpan={4}>
                        Bu donemde tahakkuga bagli basarili odeme yok.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
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
  tone?: "emerald" | "red";
}) {
  const cls =
    tone === "red"
      ? "bg-red-50 text-red-700"
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
