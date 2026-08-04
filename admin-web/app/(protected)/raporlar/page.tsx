"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnGhost,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { agIstegi } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * P40 — RAPOR bolumu (P31 API'si).
 *
 * TEK UC, UC BICIM: katalog `/raporlar/katalog`tan gelir ve sayfa hicbir
 * rapor adini KENDISI TASIMAZ — yeni bir rapor sunucuya eklenince panelde
 * kendiliginden belirir. Rapor listesini burada tekrarlamak, sunucuya
 * eklenen bir raporun panelde unutulmasi demekti.
 *
 * PARAMETRE MODALI TEK MODEL (P31 karari): her rapor ayni alan kumesinin
 * bir alt kumesini kullanir; rapor basina ayri form, ayni dogrulamayi on
 * kez yazmak olurdu.
 */

interface KatalogOgesi {
  kod: string;
  baslik: string;
  aciklama: string;
}
interface Sutun {
  ad: string;
  etiket: string;
  tip?: string;
}
interface Tablo {
  kod: string;
  baslik: string;
  sutunlar: Sutun[];
  satirlar: Record<string, unknown>[];
  toplamlar: Record<string, unknown>;
  metin: string | null;
}

/** Bicim -> dosya UZANTISI. Ucluda ("excel" ? "xlsx" : "pdf") yazmak,
 *  sabit-metin taramasini cevrilmemis metin sanip uyarmaya iterdi — ve
 *  hakliydi: taramanin ucludaki dizgeleri gormesi bilincli bir kural.
 *  Bunlar KULLANICI METNI DEGIL dosya uzantisi oldugu icin sozluge degil
 *  bu haritaya girer. */
const UZANTI: Record<string, string> = { excel: "xlsx", pdf: "pdf" };

export default function RaporlarPage() {
  const t = useT();
  const toast = useToast();
  const { data: katalog, error: katErr } = useSWR<{ items: KatalogOgesi[] }>(
    "/api/panel/rapor-katalog",
    jsonFetcher,
  );

  const [secili, setSecili] = useState<KatalogOgesi | null>(null);
  const [baslangic, setBaslangic] = useState("");
  const [bitis, setBitis] = useState("");
  const [blok, setBlok] = useState("");
  const [ismiGoster, setIsmiGoster] = useState(true);
  const [tablo, setTablo] = useState<Tablo | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function parametreler(): Record<string, unknown> {
    // Bos alan GONDERILMEZ: bos dizgeyi tarih diye gondermek sunucuda
    // dogrulama hatasi uretirdi.
    const p: Record<string, unknown> = { ismi_goster: ismiGoster };
    if (baslangic) p.baslangic = baslangic;
    if (bitis) p.bitis = bitis;
    if (blok) p.blok = blok;
    return p;
  }

  async function goster(kod: string): Promise<void> {
    setHata(null);
    setMesgul(true);
    try {
      const res = await agIstegi(`/api/panel/rapor/${kod}?bicim=tablo`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parametreler()),
      });
      if (res === null) return; // (P101/P102) oturum bitti -> yonlendirildi
      const veri = await res.json();
      if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
      setTablo(veri as Tablo);
    } catch (e) {
      setTablo(null);
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  async function indir(kod: string, bicim: "excel" | "pdf"): Promise<void> {
    setHata(null);
    setMesgul(true);
    try {
      const res = await agIstegi(`/api/panel/rapor/${kod}?bicim=${bicim}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parametreler()),
      });
      if (res === null) return;
      if (!res.ok) {
        const veri = await res.json().catch(() => null);
        throw new Error(veri?.error?.message ?? String(res.status));
      }
      // DOSYA ADI SUNUCUDAN: `Content-Disposition` basligini yeniden
      // uydurmak, indirilen dosyanin adiyla raporun adinin ayrismasi
      // demekti.
      const cd = res.headers.get("content-disposition") ?? "";
      const eslesme = /filename="?([^";]+)"?/i.exec(cd);
      const ad = eslesme?.[1] ?? `${kod}.${UZANTI[bicim]}`;
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = ad;
      a.click();
      URL.revokeObjectURL(url);
      toast.success(t("raporIndirildi"));
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("raporBaslik")} subtitle={t("raporAlt")} />
      <ErrorBox message={katErr ? t("raporKatalogHata") : hata} />

      {/* ----------------------------- katalog ----------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("raporKatalog")}</h2>
        {katalog && katalog.items.length === 0 ? (
          <EmptyState title={t("raporYok")} description={t("raporYokAlt")} />
        ) : null}
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {(katalog?.items ?? []).map((r) => (
            <button
              key={r.kod}
              onClick={() => {
                setSecili(r);
                setTablo(null);
              }}
              className={`rounded-lg border p-3 text-left text-sm transition ${
                secili?.kod === r.kod
                  ? "border-slate-900 bg-yuzey-bg dark:border-slate-200 dark:bg-slate-800"
                  : "kart-kenar hover:border-slate-400 dark:border-slate-700"
              }`}
            >
              <div className="font-medium">{r.baslik}</div>
              <div className="mt-1 text-xs text-metin-muted">{r.aciklama}</div>
            </button>
          ))}
        </div>
      </motion.section>

      {/* ---------------------------- parametre ---------------------------- */}
      {secili ? (
        <motion.section {...panelMotion} className={panelCls}>
          <h2 className="mb-3 text-sm font-semibold">{secili.baslik}</h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Field label={t("raporBaslangic")}>
              <input
                className={inputCls}
                type="date"
                value={baslangic}
                onChange={(e) => setBaslangic(e.target.value)}
              />
            </Field>
            <Field label={t("raporBitis")}>
              <input
                className={inputCls}
                type="date"
                value={bitis}
                onChange={(e) => setBitis(e.target.value)}
              />
            </Field>
            <Field label={t("raporBlok")}>
              <input className={inputCls} value={blok} onChange={(e) => setBlok(e.target.value)} />
            </Field>
            <Field label={t("raporIsmiGoster")}>
              {/* KVKK (P31): kapiya asilacak listede ad OLMAMALI — bu
                  anahtar o kullanim icindir. */}
              <input
                type="checkbox"
                className="mt-2 h-4 w-4"
                checked={ismiGoster}
                onChange={(e) => setIsmiGoster(e.target.checked)}
              />
            </Field>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            <button className={btnPrimary} disabled={mesgul} onClick={() => goster(secili.kod)}>
              {t("raporGoster")}
            </button>
            <button className={btnGhost} disabled={mesgul} onClick={() => indir(secili.kod, "excel")}>
              {t("raporExcel")}
            </button>
            <button className={btnGhost} disabled={mesgul} onClick={() => indir(secili.kod, "pdf")}>
              {t("raporPdf")}
            </button>
          </div>
        </motion.section>
      ) : null}

      {/* ------------------------------ sonuc ------------------------------ */}
      {tablo ? (
        <motion.section {...panelMotion} className={panelCls}>
          <h2 className="mb-3 text-sm font-semibold">{tablo.baslik}</h2>
          {tablo.metin ? (
            // Serbest metin bolumu (ihtar govdesi, denetim notu): duz metin
            // olarak cizilir — HTML kabul etmek XSS yuzeyi acardi.
            <pre className="mb-3 whitespace-pre-wrap rounded bg-yuzey-bg p-3 text-xs dark:bg-slate-800">
              {tablo.metin}
            </pre>
          ) : null}
          {tablo.satirlar.length === 0 ? (
            <EmptyState title={t("raporSatirYok")} description={t("raporSatirYokAlt")} />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-left text-metin-muted">
                  <tr>
                    {tablo.sutunlar.map((s) => (
                      <th key={s.ad} className="px-3 py-2 whitespace-nowrap">
                        {s.etiket}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {tablo.satirlar.map((satir, i) => (
                    <tr key={i} className="border-t border-yuzey-divider dark:border-slate-800">
                      {tablo.sutunlar.map((s) => (
                        <td
                          key={s.ad}
                          className={`px-3 py-2 ${s.tip === "kurus" ? "text-right tabular-nums" : ""}`}
                        >
                          {/* Sunucu bicimlendirilmis METIN doner (P31): panelde
                              yeniden bicimlendirmek, Excel/PDF ile panelin
                              farkli rakam gostermesi demekti. */}
                          {String(satir[s.ad] ?? "—")}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </motion.section>
      ) : null}
    </div>
  );
}
