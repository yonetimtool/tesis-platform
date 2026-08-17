"use client";

// (P167 §2.2) FINANSAL OZET — alti kart + kasalar paneli.
//
// =====================================================================
// ANIMASYONLU SAYAC KULLANILMIYOR ve bu bir tercih degil bir KURAL
// =====================================================================
// Brief acik: "Tutarlarda animasyonlu sayac KULLANMA — para sayarken
// gercek olmayan bakiye gorunur." Panonun `Kpi` bilesenin sayma
// animasyonu var (`useSayac`) ve tam bu yuzden burada KULLANILMADI:
// 0'dan 84.320,50'ye sayan bir kart, yolun her karesinde EKRANDA DURAN
// AMA DOGRU OLMAYAN bir rakam gosterir. Bir devriye sayacinda bunun
// bedeli yok; para kalemlerinde kullanicinin ekran goruntusu aldigi an
// yanlis olabilir.
//
// =====================================================================
// EXCEL / PDF — YENI UC ACILMADI
// =====================================================================
// Rapor motoru (P31) zaten `POST /raporlar/{kod}?bicim=excel|pdf` ile
// dosya uretiyor ve ayni `RaporSonuc`tan hem tablo hem dosya cikiyor.
// Panoya ozel bir disa aktarma ucu acmak, AYNI rakamlari IKINCI bir
// yerden hesaplamak olurdu — kartla dosyanin bir gun ayrismasi ancak
// boyle mumkun olur.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { BosDurum, HataDurumu, IskeletMetin, Kart } from "@/components/ui";
import { agIstegi } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kurusToTL } from "@/lib/money";

interface FinansOzet {
  borclandirilan_ay_kurus: number;
  tahsil_edilen_ay_kurus: number;
  acik_borc_kurus: number;
  kasa_toplam_kurus: number;
  icra_acik_dosya: number;
  borc_kurus: number;
  onay_bekleyen_adet: number;
  odenmis_fatura_ay_kurus: number;
}

interface KasaBakiye {
  kasa_id: string;
  kod: string;
  ad: string;
  bakiye_kurus: number;
}

interface KasaYanit {
  items: KasaBakiye[];
  genel_toplam_kurus: number;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const BICIM_EXCEL = "excel" as const;
const BICIM_PDF = "pdf" as const;
/** Indirilen dosyanin uzantisi — ucluda dize yazilmaz. */
const UZANTI_EXCEL = "xlsx";
const UZANTI_PDF = "pdf";
/** Degeri olmayan alan icin tire — "0" yazmak yanlis bilgi olurdu. */
const YOK_ISARETI = "—";

/** Kart tanimlari — ikon YOLU, etiket ANAHTARI, degeri OKUYAN fonksiyon. */
const KARTLAR: {
  anahtar: SozlukAnahtari;
  yol: string;
  deger: (o: FinansOzet) => number | undefined;
  /** Para mi, adet mi? Adet kartinda para birimi yazmak yanlis olurdu. */
  para: boolean;
  href: string;
}[] = [
  { anahtar: "panoFinansBorclandirilan", yol: "M12 5v14M5 12h14", para: true,
    deger: (o) => o.borclandirilan_ay_kurus, href: "/dues" },
  { anahtar: "panoFinansTahsilEdilen", yol: "M20 6L9 17l-5-5", para: true,
    deger: (o) => o.tahsil_edilen_ay_kurus, href: "/finans?tip=tahsilat" },
  { anahtar: "panoFinansBorclarim", yol: "M12 19V5M5 12l7 7 7-7", para: true,
    deger: (o) => o.borc_kurus, href: "/finans?tip=gider" },
  { anahtar: "panoFinansAlacaklarim", yol: "M12 5v14M5 12l7-7 7 7", para: true,
    deger: (o) => o.acik_borc_kurus, href: "/dues" },
  { anahtar: "panoFinansOnayBekleyen", yol: "M12 7.5V12l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
    para: false, deger: (o) => o.onay_bekleyen_adet, href: "/finans" },
  { anahtar: "panoFinansOdenmisFatura", yol: "M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6",
    para: true, deger: (o) => o.odenmis_fatura_ay_kurus, href: "/finans?tip=gider" },
];

/** Excel simgesi — YESIL TABLO (brief: "taninabilir ikonlar"). */
function ExcelIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true"
      fill="none" stroke="currentColor" strokeWidth="1.75"
      strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 10h18M9 4v16" />
      <path d="M13 13l4 4M17 13l-4 4" />
    </svg>
  );
}

/** PDF simgesi — KIRMIZI BELGE. */
function PdfIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true"
      fill="none" stroke="currentColor" strokeWidth="1.75"
      strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" />
      <path d="M14 3v5h5" />
      <path d="M9 14h1.5a1.25 1.25 0 0 1 0 2.5H9zM9 14v5M14 14v5h1a1.5 1.5 0 0 0 1.5-1.5v-2A1.5 1.5 0 0 0 15 14z" />
    </svg>
  );
}

/**
 * DISA AKTARMA IKONLARI — bir tablonun sag ustunde.
 *
 * RENK IKONDA, DUGMEDE DEGIL: Excel yesil, PDF kirmizi. Dugmenin
 * kendisi notr kalir, yoksa iki renkli dugme kartin basligiyla
 * yarisirdi. Renk burada bir DURUM sinyali degil bir TANIMA isareti —
 * kullanici o iki rengi zaten dosya turleriyle esitliyor.
 */
function DisaAktar({ kod }: { kod: string }) {
  const t = useT();
  const toast = useToast();
  const [calisan, setCalisan] = useState<string | null>(null);

  async function indir(bicim: "excel" | "pdf") {
    setCalisan(bicim);
    try {
      // DOSYA `agIstegi` ILE: `apiSend` JSON bekler ve ikili govdeyi
      // ayristirmaya calisirdi. `agIstegi` 401'i de isler (oturum dustuyse
      // kullaniciyi girise yollar) — ham `fetch` o davranisi kaybederdi.
      const yanit = await agIstegi(`/api/panel/rapor/${kod}?bicim=${bicim}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      if (!yanit || !yanit.ok) throw new Error(t("panoIndirilemedi"));
      const blob = await yanit.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${kod}.${bicim === BICIM_EXCEL ? UZANTI_EXCEL : UZANTI_PDF}`;
      a.click();
      // OBJE URL'I SERBEST BIRAKILIR: birakilmazsa sekme kapanana kadar
      // her indirme bellekte bir kopya birakirdi.
      URL.revokeObjectURL(url);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("panoIndirilemedi"));
    } finally {
      setCalisan(null);
    }
  }

  const dugme = (
    bicim: "excel" | "pdf",
    etiket: string,
    renk: string,
    ikon: React.ReactNode,
  ) => (
    <button
      type="button"
      onClick={() => void indir(bicim)}
      disabled={calisan !== null}
      aria-label={etiket}
      title={etiket}
      className="odak-ic flex h-8 w-8 items-center justify-center rounded-lg transition disabled:opacity-50"
      style={{ color: renk }}
    >
      {ikon}
    </button>
  );

  return (
    <span className="flex shrink-0 items-center gap-1">
      {dugme(BICIM_EXCEL, t("panoExcelIndir"), "var(--yz-success-ink)", <ExcelIkonu />)}
      {dugme(BICIM_PDF, t("panoPdfIndir"), "var(--yz-danger-ink)", <PdfIkonu />)}
    </span>
  );
}

export function PanoFinansOzeti() {
  const t = useT();
  const { data, error, isLoading } = useSWR<FinansOzet>(
    "/api/panel/finans-ozet",
    jsonFetcher,
  );
  const { data: kasalar } = useSWR<KasaYanit>(
    "/api/panel/kasa-bakiyeleri",
    jsonFetcher,
  );

  if (error) return <HataDurumu mesaj={t("ortakHataOlustu")} />;
  if (isLoading || !data) return <IskeletMetin satir={4} />;

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {KARTLAR.map((k) => (
          <Kart key={k.anahtar} as="a" {...{ href: k.href }} className="p-kart">
            <span className="flex items-start justify-between gap-2">
              <span className="min-w-0">
                <span
                  className="flex items-center gap-2"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
                >
                  <svg viewBox="0 0 24 24" className="h-4 w-4 shrink-0" aria-hidden="true"
                    fill="none" stroke="currentColor" strokeWidth="1.75"
                    strokeLinecap="round" strokeLinejoin="round">
                    <path d={k.yol} />
                  </svg>
                  <span className="truncate">{t(k.anahtar)}</span>
                </span>
                {/* TUTAR DOGRUDAN YAZILIR — sayma animasyonu YOK (bkz.
                    dosya basligi). `tabular-nums`: rakamlar esit
                    genislikte, yani kartlar arasi hizalama kaymaz. */}
                <span
                  className="mt-1 block tabular-nums"
                  style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}
                >
                  {/* ALAN EKSIKSE "—": eski bir sunucu surumu ya da
                      yetkisi olmayan bir rol bu alani hic gondermeyebilir.
                      `undefined`i 0 diye cizmek, veriyi sizdirmadan
                      YANLIS bilgi vermek olurdu (mali halkadaki kararin
                      aynisi). */}
                  {k.deger(data) === undefined
                    ? YOK_ISARETI
                    : k.para
                      ? kurusToTL(k.deger(data) as number)
                      : k.deger(data)}
                </span>
              </span>
            </span>
          </Kart>
        ))}
      </div>

      <Kart className="p-kart">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("panoKasalar")}
          </span>
          <span className="flex items-center gap-3">
            <span className="text-end">
              <span className="block" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                {t("panoGenelToplam")}
              </span>
              <span className="block tabular-nums" style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                {data.kasa_toplam_kurus === undefined
                  ? YOK_ISARETI
                  : kurusToTL(data.kasa_toplam_kurus)}
              </span>
            </span>
            <DisaAktar kod="kasa_ekstresi" />
          </span>
        </div>
        {!kasalar ? (
          <IskeletMetin satir={2} />
        ) : (kasalar.items ?? []).length === 0 ? (
          <BosDurum baslik={t("panoKasaYok")} />
        ) : (
          <ul className="mt-3 space-y-1">
            {(kasalar.items ?? []).map((k) => (
              <li
                key={k.kasa_id}
                className="flex items-center justify-between gap-2 border-b py-1 last:border-b-0"
                style={{ borderColor: "var(--yz-border)" }}
              >
                <span className="min-w-0 truncate" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                  {k.ad}
                </span>
                <span className="shrink-0 tabular-nums" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                  {kurusToTL(k.bakiye_kurus)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Kart>
    </div>
  );
}
