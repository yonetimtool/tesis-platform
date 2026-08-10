"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import {
  ErrorBox,
  PageHeader,
  btnGhost,
  btnPrimary,
  cardCls,
} from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 7.3) KURULUM SIHIRBAZI.
 *
 * Brief: "Adim adim kurulum sihirbazi: Blok → Kat/daire → Daire tipleri →
 * Sakinler → Personel → Gorev alanlari → NFC noktalari → Aidat tanimi.
 * Ilerleme gostergesi, atlanabilir adimlar, yarim birakip devam edebilme,
 * tamamlananlarin kalici isaretlenmesi, bitince ayarlardan tekrar
 * acilabilme."
 *
 * SIHIRBAZ KENDI FORMLARINI CIZMEZ — VAR OLAN EKRANLARA YOLLAR. Sekiz
 * adimin sekizinin de calisan bir ekrani zaten var. Sihirbaz icinde
 * ikinci bir "blok ekle" formu yazmak, ayni dogrulamayi iki yerde tutmak
 * ve biri degistiginde otekini unutmak olurdu.
 *
 * ADIMLAR KILITLI DEGIL: sirali cizilir (blok olmadan daire, daire
 * olmadan sakin anlamsizdir) ama hicbiri otekini engellemez. Kilitlemek,
 * brief'in "yarim birakip devam edebilme" sartiyla celisirdi — yarim
 * birakan kullanici geri donunce kaldigi yerden DEGIL, istedigi yerden
 * devam eder.
 *
 * TAMAMLANMA SUNUCUDAN GELIR, BURADA HESAPLANMAZ: "bu adim bitti mi"
 * karari `routers/kurulum.py`de tek yerde durur. Istemcide tekrar etmek,
 * iki farkli yanit uretebilecek ikinci bir kaynak olurdu.
 */

interface Adim {
  kod: string;
  sayi: number;
  tamam: boolean;
  atlandi: boolean;
}
interface Durum {
  adimlar: Adim[];
  toplam: number;
  gecilen: number;
}

/** Adim kodu -> (etiket, aciklama, gidilecek ekran). */
const HEDEF: Record<
  string,
  { etiket: SozlukAnahtari; aciklama: SozlukAnahtari; rota: string }
> = {
  blok: {
    etiket: "kurulumBlok",
    aciklama: "kurulumBlokAlt",
    rota: "/building-editor",
  },
  daire: {
    etiket: "kurulumDaire",
    aciklama: "kurulumDaireAlt",
    rota: "/building-editor",
  },
  daire_tipi: {
    etiket: "kurulumDaireTipi",
    aciklama: "kurulumDaireTipiAlt",
    rota: "/tanimlar?defter=unit-tipleri",
  },
  sakin: {
    etiket: "kurulumSakin",
    aciklama: "kurulumSakinAlt",
    rota: "/users",
  },
  personel: {
    etiket: "kurulumPersonel",
    aciklama: "kurulumPersonelAlt",
    rota: "/tanimlar?defter=personel-kayitlari",
  },
  gorev_alani: {
    etiket: "kurulumGorevAlani",
    aciklama: "kurulumGorevAlaniAlt",
    rota: "/tasks",
  },
  nfc_noktasi: {
    etiket: "kurulumNfc",
    aciklama: "kurulumNfcAlt",
    rota: "/checkpoints",
  },
  aidat: {
    etiket: "kurulumAidat",
    aciklama: "kurulumAidatAlt",
    rota: "/dues",
  },
};

const UC = "/api/panel/kurulum";

export default function KurulumPage() {
  const t = useT();
  const [hata, setHata] = useState<string | null>(null);
  const { data, error, mutate } = useSWR<Durum>(UC, jsonFetcher);

  async function atla(kod: string, deger: boolean) {
    setHata(null);
    try {
      await apiSend(UC, "PATCH", { kod, atla: deger });
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const yuzde = data ? Math.round((data.gecilen / data.toplam) * 100) : 0;
  const bitti = data ? data.gecilen === data.toplam : false;

  return (
    <div className="space-y-4">
      <PageHeader title={t("kurulumBaslik")} subtitle={t("kurulumAlt")} />
      <ErrorBox message={hata ?? (error ? t("kurulumHata") : null)} />

      {data && (
        <section className={`${cardCls} p-kart`} aria-label={t("kurulumIlerleme")}>
          <div className="flex items-center justify-between gap-3">
            <span className="text-sm font-medium text-metin-body">
              {bitti ? t("kurulumTamamlandi") : t("kurulumIlerleme")}
            </span>
            <span className="text-sm tabular-nums text-metin-muted">
              {t("kurulumSayac", { gecilen: data.gecilen, toplam: data.toplam })}
            </span>
          </div>
          {/* ILERLEME CUBUGU ekran okuyucuya da anlatilir: gorsel bir
              dolgunun tek basina hicbir sey soylemedigi tek kullanici
              grubu tam da bu. */}
          <div
            role="progressbar"
            aria-valuenow={yuzde}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={t("kurulumIlerleme")}
            className="mt-2 h-2 w-full overflow-hidden rounded-full bg-yuzey-divider"
          >
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${yuzde}%` }}
            />
          </div>
        </section>
      )}

      <ol className="space-y-2">
        {(data?.adimlar ?? []).map((a, i) => {
          const h = HEDEF[a.kod];
          if (!h) return null;
          return (
            <li key={a.kod} className={`${cardCls} p-kart`}>
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="flex items-center gap-2 text-sm font-medium text-metin-body">
                    <span
                      // SAYI DA ROZET DE ANLAM TASIR: yalniz renk kullanmak,
                      // renk ayirt edemeyen kullanici icin bilgiyi silerdi.
                      className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs ${
                        a.tamam
                          ? "bg-accent-green/15 text-vurguInk-green"
                          : a.atlandi
                            ? "bg-yuzey-divider text-metin-muted"
                            : "bg-accent-blue/12 text-accent-blue"
                      }`}
                    >
                      {i + 1}
                    </span>
                    {t(h.etiket)}
                    <span className="text-xs font-normal text-metin-muted">
                      {a.tamam
                        ? t("kurulumAdimTamam", { sayi: a.sayi })
                        : a.atlandi
                          ? t("kurulumAdimAtlandi")
                          : t("kurulumAdimBekliyor")}
                    </span>
                  </p>
                  <p className="mt-1 text-xs text-metin-muted">{t(h.aciklama)}</p>
                </div>
                <div className="flex shrink-0 flex-wrap gap-2">
                  <Link href={h.rota} className={a.tamam ? btnGhost : btnPrimary}>
                    {a.tamam ? t("kurulumGoruntule") : t("kurulumGit")}
                  </Link>
                  {/* ATLAMA yalniz BITMEMIS adimda anlamli; biten bir adimi
                      atlamak kullaniciya hicbir sey kazandirmaz. */}
                  {!a.tamam && (
                    <button
                      type="button"
                      className={btnGhost}
                      onClick={() => void atla(a.kod, !a.atlandi)}
                    >
                      {a.atlandi ? t("kurulumAtlamayiGeriAl") : t("kurulumAtla")}
                    </button>
                  )}
                </div>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
