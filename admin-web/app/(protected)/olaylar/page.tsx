"use client";

// (P126.4) OLAYLAR — güvenliğin ihlal/olay bildirimi.
//
// KAYNAK `manuel` SABİTLENİR: bu ekrandan açılan her kayıt elle
// bildirilmiştir. `kamera` ANPR/görüntü işlemeden, `devriye` tur akışından
// gelir; kullanıcıya kaynak seçtirmek, otomatik üretilmiş bir kaydı elle
// taklit etmesine izin vermek olurdu — olay kaydının kanıt değeri buradan
// gelir.
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

type Olay = {
  id: string;
  baslik: string;
  aciklama: string | null;
  kaynak: string;
  konum: string | null;
  durum: string;
  created_at: string;
};

// METIN DEGIL KIMLIK (modul duzeyi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  yeni: "olayYeni",
  inceleniyor: "olayInceleniyor",
  kapatildi: "olayKapatildi",
};
const KAYNAK_ANAHTARI: Record<string, SozlukAnahtari> = {
  kamera: "olayKaynakKamera",
  manuel: "olayKaynakManuel",
  devriye: "olayKaynakDevriye",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  return "olayDurumBilinmiyor";
}

function kaynakAnahtari(kaynak: string): SozlukAnahtari {
  const a = KAYNAK_ANAHTARI[kaynak];
  if (a) return a;
  return "olayDurumBilinmiyor";
}

export default function OlaylarPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Olay[] }>(
    "/api/violations?limit=50&offset=0",
    jsonFetcher,
  );

  const [baslik, setBaslik] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [konum, setKonum] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  const kayitlar = data?.items ?? [];

  async function bildir() {
    if (!baslik.trim()) {
      setHata(t("olayBaslikZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      await apiSend("/api/violations", "POST", {
        baslik: baslik.trim(),
        aciklama: aciklama.trim() || null,
        // Bkz. dosya basligi: kaynak SABIT.
        kaynak: "manuel",
        konum: konum.trim() || null,
      });
      setBaslik("");
      setAciklama("");
      setKonum("");
      toast.success(t("olayBildirildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("olayBaslik")} />

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("olayYeniBildir")}</h2>
        <div className="grid gap-4">
          <Field label={t("olayKonu")}>
            <input
              className={inputCls}
              value={baslik}
              onChange={(e) => setBaslik(e.target.value)}
              maxLength={200}
            />
          </Field>
          <Field label={t("olayKonum")}>
            <input
              className={inputCls}
              value={konum}
              onChange={(e) => setKonum(e.target.value)}
              maxLength={200}
            />
          </Field>
          <Field label={t("olayAciklama")}>
            <textarea
              className={`${inputCls} min-h-24`}
              value={aciklama}
              onChange={(e) => setAciklama(e.target.value)}
              maxLength={5000}
            />
          </Field>
        </div>
        <ErrorBox message={hata} />
        <div>
          <button
            className={btnPrimary}
            disabled={gonderiyor}
            onClick={() => void bildir()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("olayBildir")}
          </button>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">{t("olayListe")}</h2>
        {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <EmptyState title={t("olayYok")} />
        ) : null}
        {kayitlar.map((o) => (
          <article key={o.id} className={`${cardCls} space-y-1 p-4`}>
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">{o.baslik}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(o.durum))}
              </span>
            </div>
            <p className="text-xs text-muted">
              {tarihSaatUzun(o.created_at)} · {t(kaynakAnahtari(o.kaynak))}
              {o.konum ? ` · ${o.konum}` : ""}
            </p>
            {o.aciklama ? <p className="text-sm">{o.aciklama}</p> : null}
          </article>
        ))}
      </section>
    </div>
  );
}
