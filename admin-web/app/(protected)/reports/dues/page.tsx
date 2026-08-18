"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { EksikVeriUyarisi } from "@/components/form";
import {
  Alan,
  AlanSarmal,
  Dugme,
  Kart,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { ReportsTabs } from "@/components/ReportsTabs";
import { kisaKimlik } from "@/lib/kimlik";
import { ODEME_YONTEM, enumAdi } from "@/lib/enum-adlari";
import { fetchAllPaged } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { kurusToTL } from "@/lib/money";
import type { DuesAssessment, DuesPayment, UnitList } from "@/lib/types";
import { useI18n, useT } from "@/lib/i18n/kullan";

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
  const t = useT();
  const [donem, setDonem] = useState("");
  const [busy, setBusy] = useState(false);
  const { dil } = useI18n();
  // Yuzde birimi DILE BAGLI (tr "%78", en "78%"); `Intl` koyar.
  const yuzde = useMemo(() => {
    const b = new Intl.NumberFormat(dil, { style: "percent", maximumFractionDigits: 0 });
    return (n: number) => b.format(n / 100);
  }, [dil]);
  const [err, setErr] = useState<string | null>(null);
  const [report, setReport] = useState<Report | null>(null);
  /** (P65) Eski odeme taramasi ust sinira takildi mi — rapor EKSIKTIR. */
  const [eskiKesildi, setEskiKesildi] = useState(false);

  // Daire no haritasi (ilk 200; daha fazlasi varsa not dusulur).
  const { data: units, error: unitsErr } = useSWR<UnitList>("/api/units?limit=200&offset=0", jsonFetcher);
  const unitTruncated = Boolean(units && units.meta.total > units.items.length);
  function unitNo(id: string): string {
    return units?.items.find((u) => u.id === id)?.no ?? kisaKimlik(id);
  }

  async function run(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setReport(null);
    if (!donem.trim()) {
      setErr(t("raporDonemGerekli"));
      return;
    }
    setBusy(true);
    try {
      const d = donem.trim();
      // donem'li odemeler SUNUCUDAN suzulur (payment.donem — backend yeni alan);
      // tum liste yalniz ESKI (donem'i null) kayitlarin tahakkuk uzerinden
      // atfedilmesi + "donemsiz" uyarisi icin cekilir.
      // (P65) UCUNCU CEKIM SUZGECSIZDIR ve BUYUR: yalnizca ESKI (donem'i
      // null) kayitlari tahakkuk uzerinden atfetmek icin var. 200.000
      // odemesi olan bir sitede tarayici 1.000 ardisik istek atardi.
      // Artik ust sinirli ve kirpilirsa KULLANICIYA SOYLENIYOR.
      const [assessments, donemPayments, eski] = await Promise.all([
        fetchAllPaged<DuesAssessment>(`/api/dues/assessments?donem=${encodeURIComponent(d)}`),
        fetchAllPaged<DuesPayment>(`/api/dues/payments?donem=${encodeURIComponent(d)}`),
        fetchAllPaged<DuesPayment>("/api/dues/payments"),
      ]);
      const allPayments = eski.items;
      // Donem suzgecli iki cekim de kirpilabilir; UCUNU DE ayni not
      // kapsar — hangisinin kirpildigini soylemek kullaniciya bir sey
      // katmaz, "bu rapor eksik olabilir" bilgisi katar.
      setEskiKesildi(
        eski.kesildi || assessments.kesildi || donemPayments.kesildi,
      );

      // Donem tahakkuklari (kurus, tam sayi).
      const tahakkukByUnit = new Map<string, number>();
      const sonOdemeByUnit = new Map<string, string | null>();
      const periodAssessmentIds = new Set<string>();
      for (const a of assessments.items) {
        tahakkukByUnit.set(a.unit_id, (tahakkukByUnit.get(a.unit_id) ?? 0) + a.tutar_kurus);
        sonOdemeByUnit.set(a.unit_id, a.son_odeme_tarihi ?? null);
        periodAssessmentIds.add(a.id);
      }

      // Doneme atfedilen basarili odemeler:
      //  1) payment.donem == secili donem (sunucu suzdu; serbest odemeler DAHIL)
      //  2) eski kayitlar (donem null) — bu donemin tahakkuguna bagliysa
      const atfedilen = new Map<string, DuesPayment>();
      for (const p of donemPayments.items) {
        if (p.durum === "basarili") atfedilen.set(p.id, p);
      }
      let serbestBasariliSayi = 0; // hala doneme atfedilemeyenler (eski: donem null + tahakkuksuz)
      for (const p of allPayments) {
        if (p.durum !== "basarili" || p.donem) continue;
        if (p.assessment_id && periodAssessmentIds.has(p.assessment_id)) {
          atfedilen.set(p.id, p);
        } else if (!p.assessment_id) {
          serbestBasariliSayi += 1;
        }
      }

      const odenenByUnit = new Map<string, number>();
      const odemeler: OdemeRow[] = [];
      for (const p of atfedilen.values()) {
        odenenByUnit.set(p.unit_id, (odenenByUnit.get(p.unit_id) ?? 0) + p.tutar_kurus);
        odemeler.push({
          id: p.id,
          no: unitNo(p.unit_id),
          tutar: p.tutar_kurus,
          yontem: p.yontem,
          zaman: p.odeme_zamani,
        });
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
      setErr(e2 instanceof Error ? e2.message : t("raporOlusturulamadi"));
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

  const borcKolonlari: Kolon<BorcRow>[] = useMemo(
    () => [
      { id: "no", baslik: t("raporTabloDaire"), gizlenebilir: false, hucre: (b) => b.no },
      {
        id: "tahakkuk",
        baslik: t("raporTabloTahakkuk"),
        sayisal: true,
        deger: (b) => b.tahakkuk,
        hucre: (b) => kurusToTL(b.tahakkuk),
      },
      {
        id: "odenen",
        baslik: t("raporOdenen"),
        sayisal: true,
        deger: (b) => b.odenen,
        hucre: (b) => kurusToTL(b.odenen),
      },
      {
        id: "kalan",
        baslik: t("raporKalanBorc"),
        sayisal: true,
        deger: (b) => b.kalan,
        hucre: (b) => (
          <span style={{ color: "var(--yz-danger-ink)", fontWeight: 600 }}>
            {kurusToTL(b.kalan)}
          </span>
        ),
      },
      {
        id: "son",
        baslik: t("aidatSonOdemeKisa"),
        darEkrandaGizle: true,
        hucre: (b) => b.son_odeme ?? "—",
      },
    ],
    [t],
  );

  const odemeKolonlari: Kolon<OdemeRow>[] = useMemo(
    () => [
      { id: "no", baslik: t("raporTabloDaire"), gizlenebilir: false, hucre: (o) => o.no },
      {
        id: "tutar",
        baslik: t("raporTabloTutar"),
        sayisal: true,
        deger: (o) => o.tutar,
        hucre: (o) => <span className="font-medium">{kurusToTL(o.tutar)}</span>,
      },
      {
        id: "yontem",
        baslik: t("aidatYontem"),
        hucre: (o) => enumAdi(t, ODEME_YONTEM, o.yontem),
      },
      {
        id: "zaman",
        baslik: t("raporTabloZaman"),
        darEkrandaGizle: true,
        hucre: (o) => formatDateTime(o.zaman),
      },
    ],
    [t],
  );

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("raporAidatTahsilatBaslik")}
      </h1>

      <EksikVeriUyarisi mesaj={unitsErr ? t("ortakSecenekYuklenemedi") : null} />

      <Kart>
        <form onSubmit={run} className="flex items-end gap-3">
          <div className="w-56">
            <AlanSarmal etiket={t("ortakDonem")} ipucu={t("raporDonemOrnek")}>
              {(b) => (
                <Alan
                  {...b}
                  value={donem}
                  onChange={(e) => setDonem(e.target.value)}
                  placeholder="2026-06"
                />
              )}
            </AlanSarmal>
          </div>
          <Dugme tur="birincil" type="submit" disabled={busy} yukleniyor={busy}>
            {busy ? t("raporHesaplaniyor") : t("raporGetir")}
          </Dugme>
        </form>
      </Kart>

      {err && (
        <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
          {err}
        </p>
      )}
      {/* (P65) SESSIZ KIRPMA YOK: ust sinira takilan tarama, EKSIK bir
          raporu tam sanmak demektir. */}
      {eskiKesildi && (
        <p role="status" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
          {t("raporEskiOdemeKesildi")}
        </p>
      )}
      {unitTruncated && (
        <p role="status" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
          {t("raporDaireNotu")}
        </p>
      )}

      {report && (
        <>
          {/* OZET — PARA, o yuzden SAYACSIZ (bkz. /finans karari): sayan
              bir rakam, animasyon boyunca gercek olmayan bir tutar
              gosterir ve bu ekranda o tutarlar karar dayanagidir. */}
          <div className="grid gap-3 md:grid-cols-4">
            <OzetKart etiket={t("raporToplamTahakkuk")} deger={kurusToTL(report.toplamTahakkuk)} />
            <OzetKart
              etiket={t("raporToplamTahsilat")}
              deger={kurusToTL(report.toplamTahsilat)}
              renk="var(--yz-success-ink)"
            />
            <OzetKart
              etiket={t("raporBakiyeBorc")}
              deger={kurusToTL(report.bakiye)}
              renk={report.bakiye > 0 ? "var(--yz-danger-ink)" : "var(--yz-success-ink)"}
            />
            {/* (P160) `% 78` ELLE kuruluyordu — Turkce yazim, yedi dilin
                altisinda yanlis. `Intl` birimi aktif dile gore koyar. */}
            <OzetKart etiket={t("raporTahsilatOrani")} deger={yuzde(report.oranYuzde)} />
          </div>
          <div className="grid gap-3 md:grid-cols-3">
            <OzetKart etiket={t("raporTahakkukEdilenDaire")} deger={String(report.daireTahakkuk)} />
            <OzetKart
              etiket={t("raporTamOdeyen")}
              deger={String(report.daireTamOdeyen)}
              renk="var(--yz-success-ink)"
            />
            <OzetKart
              etiket={t("raporBorcluDaire")}
              deger={String(report.daireBorclu)}
              renk={report.daireBorclu > 0 ? "var(--yz-danger-ink)" : "var(--yz-success-ink)"}
            />
          </div>

          {report.serbestBasariliSayi > 0 && (
            <p role="status" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
              {t("raporDonemsizNot", { sayi: report.serbestBasariliSayi })}
            </p>
          )}

          {/* Borclu daireler */}
          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("raporBorcluDaireler")}
              </h2>
              <Dugme
                boy="kucuk"
                onClick={() => void exportBorclular()}
                disabled={report.borclular.length === 0}
              >
                {t("raporCsvIndir")}
              </Dugme>
            </div>
            <VeriTablosu<BorcRow>
              kolonlar={borcKolonlari}
              // `?? []`: yanit bu alani hic tasimazsa tablo BOS cizilir.
              // Eskiden `undefined` gecip bileseni COKERTIYORDU ve sayfanin
              // tamami React hata siniriyla kayboluyordu (takim kosumunda
              // yakalanmamis istisna olarak goruldu).
              satirlar={report.borclular ?? []}
              satirId={(b) => b.unit_id}
              bosBaslik={t("raporBorcluYok")}
              bosAciklama={t("raporBorcluYokAlt")}
            />
          </section>

          {/* Odemeler */}
          <section className="space-y-2">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("raporDonemTahsilatlari")}
            </h2>
            <VeriTablosu<OdemeRow>
              kolonlar={odemeKolonlari}
              satirlar={report.odemeler ?? []}
              satirId={(o) => o.id}
              bosBaslik={t("aidatOdemeYok")}
              bosAciklama={t("raporOdemeYok")}
            />
          </section>
        </>
      )}
    </div>
  );
}

/** Ozet kutusu — para/sayilar SAYACSIZ (gerekce yukarida). */
function OzetKart({ etiket, deger, renk }: { etiket: string; deger: string; renk?: string }) {
  return (
    <Kart className="!p-4">
      <div style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{etiket}</div>
      <div
        className="mt-1 tabular-nums"
        style={{
          fontSize: "var(--yz-fs-h3)",
          fontWeight: "var(--yz-fw-kpi)" as unknown as number,
          color: renk ?? "var(--yz-text)",
        }}
      >
        {deger}
      </div>
    </Kart>
  );
}
