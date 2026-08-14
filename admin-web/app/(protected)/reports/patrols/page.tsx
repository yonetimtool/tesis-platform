"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { EksikVeriUyarisi } from "@/components/form";
import {
  Alan,
  AlanSarmal,
  Dugme,
  TarihAraligi,
  aralikGecerli,
  Kart,
  Kpi,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { ReportsTabs } from "@/components/ReportsTabs";
import { TUR_DURUM, enumAdi } from "@/lib/enum-adlari";
import { fetchAllPaged } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { PatrolPlanList, PatrolWindowListResponse, PatrolWindowRow } from "@/lib/types";
import { useI18n, useT } from "@/lib/i18n/kullan";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const D_OLUMLU = "olumlu" as const;
const D_KRITIK = "kritik" as const;
const D_UYARI = "uyari" as const;
const D_NOTR = "notr" as const;

/** Pencere durumu -> rozet/halka rengi. */
const DURUM_RENGI: Record<string, typeof D_OLUMLU | typeof D_KRITIK | typeof D_UYARI> = {
  tamamlandi: D_OLUMLU,
  kacirildi: D_KRITIK,
  bekliyor: D_UYARI,
};

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

export default function PatrolReportPage() {
  const t = useT();
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [durum, setDurum] = useState("");
  const [planId, setPlanId] = useState("");
  /** (P65) Cekim ust sinira takildi mi — rapor EKSIKTIR. */
  const [kesildi, setKesildi] = useState(false);
  const [committed, setCommitted] = useState<string | null>(null);
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const { dil } = useI18n();
  // (P160) YUZDE BICIMI DILE BAGLI. Deger `"% 78"` diye ELLE kuruluyordu;
  // bu Turkce yazimdir ve yedi dilin altisinda yanlisti (en. "78%").
  // `Intl` birimi aktif dile gore koyar.
  const yuzde = useMemo(() => {
    const b = new Intl.NumberFormat(dil, { style: "percent", maximumFractionDigits: 0 });
    return (n: number) => b.format(n / 100);
  }, [dil]);

  const { data: plans, error: plansErr } = useSWR<PatrolPlanList>("/api/patrol-plans?limit=200&offset=0", jsonFetcher);

  function buildFilters(): string {
    const qs = new URLSearchParams();
    const b = toIso(bas);
    if (b) qs.set("baslangic", b);
    const e = toIso(bit);
    if (e) qs.set("bitis", e);
    if (durum) qs.set("durum", durum);
    if (planId) qs.set("patrol_plan_id", planId);
    return qs.toString();
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setCommitted(buildFilters());
    setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
  }

  const key =
    committed !== null
      ? `/api/patrol-windows?${[committed, `limit=${tabloDurumu.boy}`, `offset=${offset}`]
          .filter(Boolean)
          .join("&")}`
      : null;
  const { data, error, isLoading } = useSWR<PatrolWindowListResponse>(key, jsonFetcher);

  const oranSayi =
    data && data.ozet.toplam > 0
      ? Math.floor((data.ozet.tamamlandi * 100) / data.ozet.toplam)
      : 0;

  async function exportCsv() {
    if (committed === null) return;
    const cekim = await fetchAllPaged<PatrolWindowRow>(
      `/api/patrol-windows?${committed}`,
    );
    setKesildi(cekim.kesildi);
    const items = cekim.items;
    const rows: string[][] = [
      ["Plan", "Baslangic", "Bitis", t("ortakDurum"), "Okutulan", "Beklenen"],
    ];
    for (const w of items) {
      rows.push([
        w.plan_adi ?? "",
        w.pencere_baslangic,
        w.pencere_bitis,
        w.durum,
        String(w.okutulan_checkpoint_sayisi),
        String(w.beklenen_checkpoint_sayisi),
      ]);
    }
    csvDownload("tur-gecmisi.csv", rows);
  }

  const planSecenekleri = (plans?.items ?? []).map((p) => (
    <option key={p.id} value={p.id}>
      {p.ad}
    </option>
  ));

  const kolonlar: Kolon<PatrolWindowRow>[] = useMemo(
    () => [
      {
        id: "plan",
        baslik: t("raporTabloPlan"),
        gizlenebilir: false,
        hucre: (w) => w.plan_adi ?? "—",
      },
      {
        id: "bas",
        baslik: t("ortakBaslangic"),
        hucre: (w) => formatDateTime(w.pencere_baslangic),
      },
      {
        id: "bit",
        baslik: t("ortakBitis"),
        darEkrandaGizle: true,
        hucre: (w) => formatDateTime(w.pencere_bitis),
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (w) => (
          <Rozet durum={DURUM_RENGI[w.durum] ?? D_NOTR}>
            {enumAdi(t, TUR_DURUM, w.durum)}
          </Rozet>
        ),
      },
      {
        id: "cp",
        baslik: t("raporTabloCheckpoint"),
        sayisal: true,
        hucre: (w) => `${w.okutulan_checkpoint_sayisi}/${w.beklenen_checkpoint_sayisi}`,
      },
    ],
    [t],
  );

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("raporTurGecmisiBaslik")}
      </h1>

      <EksikVeriUyarisi mesaj={plansErr ? t("ortakSecenekYuklenemedi") : null} />

      <Kart>
        <form onSubmit={submit} className="flex flex-wrap items-end gap-3">
          {/* (P160) TEK BILESEN + TUTARLILIK KURALI. Iki alan ayri
              dururken bitisi baslangictan once secen kullanici BOS bir
              rapor aliyor ve sebebini goremiyordu. */}
          <TarihAraligi
            tip="datetime-local"
            ipucu={t("ortakYerelSaatOpsiyonel")}
            baslangic={bas}
            bitis={bit}
            onBaslangic={setBas}
            onBitis={setBit}
          />
          <div className="w-44">
            <AlanSarmal etiket={t("ortakDurum")}>
              {(b) => (
                <Secim {...b} value={durum} onChange={(e) => setDurum(e.target.value)}>
                  <option value="">{t("ortakTumu")}</option>
                  <option value="tamamlandi">{t("raporTamamlandi")}</option>
                  <option value="kacirildi">{t("raporKacirildi")}</option>
                  <option value="bekliyor">{t("panelBekleyen")}</option>
                </Secim>
              )}
            </AlanSarmal>
          </div>
          <div className="w-full sm:w-52">
            <AlanSarmal etiket={t("devriyePlanOpsiyonel")}>
              {(b) => (
                <Secim {...b} value={planId} onChange={(e) => setPlanId(e.target.value)}>
                  <option value="">{t("ortakTumu")}</option>
                  {planSecenekleri}
                </Secim>
              )}
            </AlanSarmal>
          </div>
          {/* Aralik TERSKEN istek ATILMAZ: bos bir rapor gostermek,
              kullaniciya "kayit yok" demek olurdu. */}
          <Dugme tur="birincil" type="submit" disabled={!aralikGecerli(bas, bit)}>
            {t("raporGetir")}
          </Dugme>
        </form>
      </Kart>

      {/* (P65) Cekim ust sinira takildi: rapor EKSIKTIR ve bunu sessiz
          gecmek, eksik bir CSV'yi tam sanmak demekti. */}
      {kesildi && (
        <p role="status" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
          {t("raporKesildi")}
        </p>
      )}
      {committed === null && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("raporFiltreSecin")}
        </p>
      )}

      {committed !== null && (
        <>
          {data && (
            <div className="grid gap-3 md:grid-cols-5">
              <Kpi deger={data.ozet.toplam} etiket={t("raporToplamPencere")} />
              <Kpi deger={data.ozet.tamamlandi} etiket={t("panelTamamlanan")} durum={D_OLUMLU} />
              <Kpi deger={data.ozet.kacirildi} etiket={t("raporKacirilan")} durum={D_KRITIK} />
              <Kpi deger={data.ozet.bekliyor} etiket={t("panelBekleyen")} durum={D_UYARI} />
              <Kpi
                deger={oranSayi}
                etiket={t("raporTamamlanmaOrani")}
                // Birim YERI dile bagli — `Intl` koyar, biz degil.
                bicimle={yuzde}
              />
            </div>
          )}

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("raporPencereler")}
              </h2>
              <Dugme
                boy="kucuk"
                onClick={() => void exportCsv()}
                disabled={(data?.items.length ?? 0) === 0}
              >
                {t("raporCsvIndir")}
              </Dugme>
            </div>
            <VeriTablosu<PatrolWindowRow>
              kolonlar={kolonlar}
              satirlar={data?.items ?? []}
              satirId={(w) => w.id}
              hata={error ? error.message : null}
              yukleniyor={isLoading && !data}
              bosBaslik={t("devriyePencereYok")}
              bosAciklama={t("raporPencereYok")}
              sunucuTarafli
              toplam={data?.meta.total ?? 0}
              durum={tabloDurumu}
              onDurumDegisti={setTabloDurumu}
            />
          </section>
        </>
      )}
    </div>
  );
}
