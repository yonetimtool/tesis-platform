"use client";

// (P192 §5.4) BUTCE — hedef ile gerceklesen YAN YANA.
//
// Uründe "butce" diye bir sey vardi ama o GERCEKLESEN defterdi;
// PLANLANAN tutari tutan hicbir yer yoktu ve "sapma" sorusu
// cevaplanamiyordu cunku karsilastirilacak ikinci sayi YOKTU.
//
// SAPMANIN ISARETI TIPE BAGLIDIR: giderde pozitif "butce asildi"
// (kotu), gelirde pozitif "hedefin uzerinde" (iyi). Bu yorumu istemciye
// birakmak, iki ekranda iki anlam demekti — renk kurali burada tek yerde.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  Kart,
  Secim,
  HataDurumu,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";

interface Satir {
  kategori_id: string | null;
  ad: string;
  tip: string;
  hedef_kurus: number;
  gerceklesen_kurus: number;
  sapma_kurus: number;
  sapma_yuzde: number | null;
}

interface Kategori {
  id: string;
  ad: string;
  tip: string;
}

export default function ButcePage() {
  const t = useT();
  const toast = useToast();
  const [yil, setYil] = useState(String(new Date().getFullYear()));
  const [kategoriId, setKategoriId] = useState("");
  const [hedef, setHedef] = useState("");

  const { data, error, isLoading, mutate } = useSWR<{ items: Satir[] }>(
    `/api/panel/butce-karsilastirma?yil=${yil}`, jsonFetcher);
  const { data: kategoriler } = useSWR<{ items: Kategori[] }>(
    "/api/panel/butce-kategorileri", jsonFetcher);

  async function hedefYaz() {
    const kurus = tlToKurus(hedef);
    if (!kategoriId || kurus === null) return;
    try {
      await apiSend("/api/panel/butce-hedefleri", "POST", {
        yil: Number(yil), kategori_id: kategoriId, tutar_kurus: kurus,
      });
      setHedef("");
      toast.success(t("finansKaydedildi"));
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const kolonlar: Kolon<Satir>[] = [
    { id: "ad", baslik: t("finansSutunTur"), hucre: (s) => s.ad },
    { id: "hedef", baslik: t("butHedef"), sayisal: true,
      hucre: (s) => <span className="tabular-nums">{kurusToTL(s.hedef_kurus)}</span>,
      deger: (s) => s.hedef_kurus },
    { id: "gercek", baslik: t("butGerceklesen"), sayisal: true,
      hucre: (s) => (
        <span className="tabular-nums">{kurusToTL(s.gerceklesen_kurus)}</span>
      ),
      deger: (s) => s.gerceklesen_kurus },
    { id: "sapma", baslik: t("butSapma"), sayisal: true,
      hucre: (s) => (
        <span
          className="tabular-nums"
          style={{
            // GIDERDE pozitif sapma UYARIDIR, gelirde iyidir.
            color:
              s.sapma_kurus === 0
                ? undefined
                : (s.tip === "gider") === s.sapma_kurus > 0
                  ? "var(--yz-danger)"
                  : "var(--yz-success)",
          }}
        >
          {kurusToTL(s.sapma_kurus)}
          {s.sapma_yuzde === null ? "" : ` (%${s.sapma_yuzde})`}
        </span>
      ),
      deger: (s) => s.sapma_kurus },
  ];

  return (
    <div className="space-y-4">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("finansButce")}
      </h1>

      <Kart>
        <div className="grid gap-3 sm:grid-cols-4">
          <AlanSarmal etiket={t("butYil")}>
            {(b) => (
              <Alan {...b} type="number" min={2000} max={2100} value={yil}
                onChange={(e) => setYil(e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansSutunTur")}>
            {(b) => (
              <Secim {...b} value={kategoriId}
                onChange={(e) => setKategoriId(e.target.value)}>
                <option value="">{t("finansTurSec")}</option>
                {(kategoriler?.items ?? []).map((k) => (
                  <option key={k.id} value={k.id}>{k.ad}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("butHedef")}>
            {(b) => (
              <Alan {...b} value={hedef} inputMode="decimal"
                onChange={(e) => setHedef(e.target.value)} />
            )}
          </AlanSarmal>
          <div className="flex items-end">
            <Dugme tur="birincil" boy="kucuk" onClick={() => void hedefYaz()}>
              {t("butHedefYaz")}
            </Dugme>
          </div>
        </div>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("butKarsilastirmaAciklama")}
        </p>
      </Kart>

      <Kart>
        {error && (
          <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => void mutate()} />
        )}
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={data?.items ?? []}
          satirId={(s) => s.kategori_id ?? s.ad}
          yukleniyor={isLoading}
          bosBaslik={t("otoKayitYok")}
        />
      </Kart>
    </div>
  );
}
