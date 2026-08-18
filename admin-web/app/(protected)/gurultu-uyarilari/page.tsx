"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Dugme, HataDurumu, VeriTablosu, type Kolon } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P167 §6.1) GURULTU UYARILARI — Yonetisim sayfasindan TASINDI.
 *
 * Brief "Yonetisim alt basligi tamamen kaldirilsin" diyor; genel kisit
 * "mevcut islev kaybolmayacak". Bu bolum o sayfanin icindeydi.
 *
 * "YAPILDI" DUGMESINI SUNUCU BASAMAZ (P37): bir uyarinin sakine gercekten
 * anons edilip edilmedigini yalnizca insan bilir. Sunucunun varsaymasi,
 * yapilmamis bir anonsu kayda gecirmek olurdu.
 */

interface Uyari {
  id: string;
  unit_no: string | null;
  esik: number;
  sayac: number;
  kanal: string;
  durum: string;
  created_at: string;
}

const BEKLEYEN = "manuel_bekliyor";
const SAYAC_AYIRACI = "/";

export default function GurultuUyarilariPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Uyari[] }>(
    "/api/panel/unit-uyarilari?limit=200",
    jsonFetcher,
  );
  const [hata, setHata] = useState<string | null>(null);

  async function yapildi(id: string): Promise<void> {
    setHata(null);
    try {
      await apiSend(`/api/panel/uyari-yapildi/${id}`, "POST");
      toast.success(t("yonUyariIsaretlendi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  const kolonlar: Kolon<Uyari>[] = useMemo(
    () => [
      {
        id: "created_at", kartRolu: "ozet",
        baslik: t("yonUyariTarih"),
        hucre: (u) => formatDateTime(u.created_at),
        deger: (u) => u.created_at,
      },
      {
        id: "unit_no", kartRolu: "baslik",
        baslik: t("yonUyariDaire"),
        hucre: (u) => u.unit_no ?? t("ortakYok"),
        deger: (u) => u.unit_no,
      },
      {
        id: "sayac", kartRolu: "ozet",
        baslik: t("yonUyariSayac"),
        sayisal: true,
        hucre: (u) => `${u.sayac}${SAYAC_AYIRACI}${u.esik}`,
        deger: (u) => u.sayac,
      },
      {
        id: "durum", kartRolu: "rozet",
        baslik: t("yonUyariDurum"),
        hucre: (u) => t(`yonUyariDurum_${u.durum}` as SozlukAnahtari),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: t("listeIslemler"),
        hucre: (u) =>
          // DUGME YALNIZ BEKLEYENDE: kapanmis bir uyariya "yapildi"
          // demek, olmayan bir eylemi sunan bir dugme olurdu.
          u.durum === BEKLEYEN ? (
            <Dugme boy="kucuk" onClick={() => void yapildi(u.id)}>
              {t("yonUyariYapildi")}
            </Dugme>
          ) : null,
      },
    ],
    [t],
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("yonUyarilar")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("gurultuAlt")}
        </p>
      </div>

      {hata ? <HataDurumu mesaj={hata} /> : null}

      <VeriTablosu<Uyari>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(u) => u.id}
        yukleniyor={isLoading}
        hata={error ? t("yonUyariHata") : null}
        onTekrar={() => void mutate()}
        bosBaslik={t("yonUyariYok")}
        bosAciklama={t("yonUyariYokAlt")}
      />
    </div>
  );
}
