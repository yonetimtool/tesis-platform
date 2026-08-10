"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnDanger,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 7.2) ANKETLER — kendi sayfasi.
 *
 * NEDEN TASINDI: anket yonetimi `/portal` ("Site sayfasi") icinde
 * yasiyordu ve brief o sayfanin KALDIRILMASINI istiyor. Ama anket
 * calisan bir ozellik ve mobil karsiligi BILEREK salt-okuma
 * ("olusturma/kapatma YONETIM isidir ve panele"). Portali oldugu gibi
 * silmek, anketi ACILAMAZ hâle getirirdi.
 *
 * UC DEGISMEDI (`/anketler`): bu bir yuzey tasima, sozlesme degisikligi
 * degil. Mobil istemci etkilenmez.
 *
 * SONUC KAPANANA KADAR GIZLI (P38) ve bu sayfa onu DEGISTIRMEZ: sayilar
 * sunucudan geldigi gibi cizilir. Gelmiyorsa hic cizilmez — SIFIR
 * UYDURULMAZ, cunku "0 oy" ile "sonuc gizli" ayni sey degildir.
 */

interface Secenek {
  id: string;
  metin: string;
  oy: number | null;
}
interface Anket {
  id: string;
  baslik: string;
  aciklama: string | null;
  acik: boolean;
  aktif: boolean;
  toplam_oy: number | null;
  secenekler: Secenek[];
}

export default function AnketlerPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);
  const [baslik, setBaslik] = useState("");
  const [secenekMetni, setSecenekMetni] = useState("");

  const {
    data: anketler,
    error: aErr,
    mutate: tazele,
  } = useSWR<{ items: Anket[] }>("/api/panel/anketler?limit=50", jsonFetcher);

  async function ekle(): Promise<void> {
    setHata(null);
    const secenekler = secenekMetni
      .split("\n")
      .map((x) => x.trim())
      .filter(Boolean)
      .map((metin, i) => ({ metin, sira: i }));
    if (!baslik.trim() || secenekler.length < 2) {
      // EN AZ IKI secenek (P38): tek secenekli anket oy toplamaz, ONAY
      // toplar — bunu sunucuya sorup 422 almak yerine burada soyluyoruz.
      setHata(t("anketEnAzIki"));
      return;
    }
    try {
      await apiSend("/api/panel/anketler", "POST", { baslik, secenekler });
      setBaslik("");
      setSecenekMetni("");
      toast.success(t("anketEklendi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function kapat(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/anketler/${id}`, "PATCH", { aktif: false });
      toast.success(t("anketKapatildi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("kabukAnketler")} subtitle={t("anketAlt")} />
      <ErrorBox message={hata ?? (aErr ? t("anketHata") : null)} />

      <motion.section {...panelMotion} className={panelCls}>
        {anketler && anketler.items.length === 0 ? (
          <EmptyState title={t("anketYok")} description={t("anketYokAlt")} />
        ) : null}

        <div className="space-y-3">
          {(anketler?.items ?? []).map((a) => (
            <div
              key={a.id}
              className="kart-kenar rounded-lg border p-3 text-sm dark:border-slate-700"
            >
              <div className="flex items-center justify-between gap-3">
                <span className="font-medium">{a.baslik}</span>
                <span className="text-xs text-metin-muted">
                  {a.acik ? t("anketAcik") : t("anketKapali")}
                  {a.toplam_oy != null ? ` · ${a.toplam_oy}` : ""}
                </span>
              </div>
              <ul className="mt-2 space-y-1 text-xs">
                {a.secenekler.map((s) => (
                  <li key={s.id} className="flex justify-between">
                    <span>{s.metin}</span>
                    {/* Yonetim sonucu HER ZAMAN gorur (P38) — sayi sunucudan
                        gelmiyorsa hic cizilmez, sifir UYDURULMAZ. */}
                    {s.oy != null ? (
                      <span className="tabular-nums">{s.oy}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
              {a.aktif ? (
                <button
                  type="button"
                  className={`${btnDanger} mt-2`}
                  onClick={() => void kapat(a.id)}
                >
                  {t("anketKapat")}
                </button>
              ) : null}
            </div>
          ))}
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <Field label={t("anketBaslik")}>
            <input
              className={inputCls}
              value={baslik}
              onChange={(e) => setBaslik(e.target.value)}
            />
          </Field>
          <Field label={t("anketSecenekler")} hint={t("anketSecenekIpucu")}>
            <textarea
              className={`${inputCls} min-h-20`}
              value={secenekMetni}
              onChange={(e) => setSecenekMetni(e.target.value)}
            />
          </Field>
        </div>
        <button
          type="button"
          className={`${btnPrimary} mt-3`}
          onClick={() => void ekle()}
        >
          {t("anketEkle")}
        </button>
      </motion.section>
    </div>
  );
}
