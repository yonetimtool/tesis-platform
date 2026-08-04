"use client";

// (P126.4) ZİYARETÇİLER — güvenliğin kapı ekranı.
//
// KAYIT YALNIZ GÜVENLİK: sunucu `_REGISTRAR = require_role("security")` ile
// zorlar; yönetici/admin geçmişi okur ama kayıt açmaz (kapı operasyonu).
// Bu sayfa `app.*` tesis yüzeyindedir ve rol kapısı girişte uygulanır.
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnGhost,
  btnPrimary,
  cardCls,
  inputCls,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Ziyaretci = {
  id: string;
  unit_no: string | null;
  ziyaretci_ad: string;
  notlar: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
};

export default function ZiyaretcilerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Ziyaretci[] }>(
    "/api/visitors?limit=50&offset=0",
    jsonFetcher,
  );

  const [ad, setAd] = useState("");
  const [daireNo, setDaireNo] = useState("");
  const [notlar, setNotlar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!ad.trim() || !daireNo.trim()) {
      setHata(t("ziyaretciAlanZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile gonderilir: kapida görevli daire NUMARASINI bilir,
      // kaydın kimliğini değil. Sunucu numarayı çözer.
      await apiSend("/api/visitors", "POST", {
        unit_no: daireNo.trim(),
        ziyaretci_ad: ad.trim(),
        notlar: notlar.trim() || null,
      });
      setAd("");
      setDaireNo("");
      setNotlar("");
      toast.success(t("ziyaretciKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function cikisYap(id: string) {
    try {
      await apiSend(`/api/visitors/${id}/checkout`, "POST");
      toast.success(t("ziyaretciCikisYapildi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("ziyaretciBaslik")} />

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("ziyaretciYeni")}</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("ziyaretciAd")}>
            <input
              className={inputCls}
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              maxLength={120}
            />
          </Field>
          <Field label={t("ziyaretciDaire")}>
            <input
              className={inputCls}
              value={daireNo}
              onChange={(e) => setDaireNo(e.target.value)}
              maxLength={30}
            />
          </Field>
          <Field label={t("ziyaretciNot")}>
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
            {gonderiyor ? t("ortakKaydediliyor") : t("ziyaretciGirisKaydet")}
          </button>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">{t("ziyaretciListe")}</h2>
        {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <EmptyState title={t("ziyaretciYok")} />
        ) : null}
        {kayitlar.map((z) => (
          <article key={z.id} className={`${cardCls} space-y-1 p-4`}>
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">{z.ziyaretci_ad}</h3>
              <span className="text-xs text-metin-muted">{z.unit_no ?? "—"}</span>
            </div>
            <p className="text-xs text-metin-muted">
              {tarihSaatUzun(z.giris_zamani)}
              {z.cikis_zamani ? ` → ${tarihSaatUzun(z.cikis_zamani)}` : ""}
            </p>
            {z.notlar ? <p className="text-sm">{z.notlar}</p> : null}
            {/* CIKIS DUGMESI yalnizca ICERIDEKI ziyaretcide: cikmis birine
                tekrar cikis yaptirmak, kaydi ikinci kez damgalamak olurdu. */}
            {!z.cikis_zamani ? (
              <button className={btnGhost} onClick={() => void cikisYap(z.id)}>
                {t("ziyaretciCikis")}
              </button>
            ) : null}
          </article>
        ))}
      </section>
    </div>
  );
}
