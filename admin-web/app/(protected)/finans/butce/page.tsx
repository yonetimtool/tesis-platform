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
import { HedefBar } from "@/components/finans/hedef-bar";
import {
  Alan,
  AlanSarmal,
  Dugme,
  Kart,
  HataDurumu,
  SayfaBasligi,
  Secim,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { ISTEMCI_SINIR } from "@/lib/girdi-siniri";

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

  /**
   * (P244 §7b) SAPMA BU SATIR ICIN KOTU MU — TEK YERDE.
   *
   * Giderde pozitif sapma "butce asildi" (kotu), gelirde "hedefin
   * uzerinde" (iyi). Hem sapma sutunu hem oran bari bu karari okur.
   */
  function sapmaKotuMu(s: Satir): boolean {
    return (s.tip === "gider") === s.sapma_kurus > 0;
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
    // (P244 §7b) GORSEL ORAN — hedefe gore nerede oldugu tek bakista.
    // Kolon `sayisal` DEGIL: icinde bir bar var, sagdan hizalanmasi
    // gerekmiyor ve tabular rakam kurali burada gecersiz.
    { id: "oran", baslik: t("butOran"),
      // SIRALAMA YINE SAYIYA gore: gorsel bir kolon da siralanabilmeli.
      deger: (s) => (s.hedef_kurus > 0 ? s.gerceklesen_kurus / s.hedef_kurus : -1),
      hucre: (s) => (
        <HedefBar
          hedefKurus={s.hedef_kurus}
          gerceklesenKurus={s.gerceklesen_kurus}
          kotuMu={sapmaKotuMu(s)}
          etiket={t("butOranEtiket", {
            ad: s.ad,
            yuzde:
              s.hedef_kurus > 0
                ? String(Math.round((s.gerceklesen_kurus / s.hedef_kurus) * 100))
                : "—",
          })}
        />
      ),
    },
    { id: "sapma", baslik: t("butSapma"), sayisal: true,
      hucre: (s) => (
        <span
          className="tabular-nums"
          style={{
            // GIDERDE pozitif sapma UYARIDIR, gelirde iyidir.
            // (P244 §7b) KURAL `sapmaKotuMu`YA CIKARILDI: bar da ayni
            // yorumu kullaniyor ve ikinci bir kopya, iki ekranda iki
            // anlam demekti. Ayrica ham `--yz-danger`/`--yz-success`
            // METIN olarak AA'yi tutmuyor (asama 1'de olculdu) — `-ink`
            // varyantina gecildi.
            color:
              s.sapma_kurus === 0
                ? undefined
                : sapmaKotuMu(s)
                  ? "var(--yz-danger-ink)"
                  : "var(--yz-success-ink)",
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
      <SayfaBasligi
        baslik={t("finansButce")}
        aciklama={t("butKarsilastirmaAciklama")}
      />

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
              <Alan maxLength={ISTEMCI_SINIR.SAYI} {...b} value={hedef} inputMode="decimal"
                onChange={(e) => setHedef(e.target.value)} />
            )}
          </AlanSarmal>
          <div className="flex items-end">
            <Dugme tur="birincil" boy="kucuk" onClick={() => void hedefYaz()}>
              {t("butHedefYaz")}
            </Dugme>
          </div>
        </div>
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
          // (E2E 2026-09) Bos tablo neden bos oldugunu soyler. Tur
          // listesi bossa ustteki secici de bos: turler bugun WEB'DE
          // ACILAMIYOR (`/budget/categories` POST yalniz mobilde), bunu
          // saklamak yoneticiyi bos bir seciciyle yalniz birakirdi.
          bosAciklama={
            kategoriler !== undefined && kategoriler.items.length === 0
              ? t("butBosTurYok")
              : t("butBosIlk")
          }
        />
      </Kart>
    </div>
  );
}
