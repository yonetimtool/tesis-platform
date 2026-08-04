"use client";

// (P126.4) KARGOLAR — güvenliğin teslimat ekranı.
//
// Kargo kapıda TESLİM ALINIR, sonra sakine TESLİM EDİLİR: iki ayrı an ve
// iki ayrı durum (`bekliyor` → `teslim_alindi`). Bu sayfa birincisini
// kaydeder ve bekleyenleri listeler.
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnPrimary,
  cardCls,
  inputCls,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihSaatUzun } from "@/lib/tarih";

type Kargo = {
  id: string;
  unit_no: string | null;
  firma: string | null;
  notlar: string | null;
  durum: string;
  created_at: string;
};

// METIN DEGIL KIMLIK (modul duzeyi — tur 18 dersi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  bekliyor: "kargoBekliyor",
  teslim_alindi: "kargoTeslimAlindi",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  // `??` tek satirda yazilirsa sabit-metin taramasi bunu bir uclu sayar.
  return "kargoDurumBilinmiyor";
}

export default function KargolarPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Kargo[] }>(
    "/api/kargo?limit=50&offset=0",
    jsonFetcher,
  );

  const [daireNo, setDaireNo] = useState("");
  const [firma, setFirma] = useState("");
  const [notlar, setNotlar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!daireNo.trim()) {
      setHata(t("kargoDaireZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile: kapidaki gorevli daire NUMARASINI bilir (ziyaretci
      // ekraniyla ayni gerekce). Sunucu numarayi cozer.
      await apiSend("/api/kargo", "POST", {
        unit_no: daireNo.trim(),
        firma: firma.trim() || null,
        notlar: notlar.trim() || null,
      });
      setDaireNo("");
      setFirma("");
      setNotlar("");
      toast.success(t("kargoKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("kargoBaslik")} />

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("kargoYeni")}</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("kargoDaire")}>
            <input
              className={inputCls}
              value={daireNo}
              onChange={(e) => setDaireNo(e.target.value)}
              maxLength={30}
            />
          </Field>
          <Field label={t("kargoFirma")}>
            <input
              className={inputCls}
              value={firma}
              onChange={(e) => setFirma(e.target.value)}
              maxLength={80}
            />
          </Field>
          <Field label={t("kargoNot")}>
            <input
              className={inputCls}
              value={notlar}
              onChange={(e) => setNotlar(e.target.value)}
              maxLength={500}
            />
          </Field>
        </div>
        <ErrorBox message={hata} />
        <div>
          <button
            className={btnPrimary}
            disabled={gonderiyor}
            onClick={() => void kaydet()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("kargoTeslimAl")}
          </button>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">{t("kargoListe")}</h2>
        {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <EmptyState title={t("kargoYok")} />
        ) : null}
        {kayitlar.map((k) => (
          <article key={k.id} className={`${cardCls} space-y-1 p-4`}>
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">{k.unit_no ?? "—"}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(k.durum))}
              </span>
            </div>
            <p className="text-xs text-metin-muted">
              {tarihSaatUzun(k.created_at)}
              {k.firma ? ` · ${k.firma}` : ""}
            </p>
            {k.notlar ? <p className="text-sm">{k.notlar}</p> : null}
          </article>
        ))}
      </section>
    </div>
  );
}
