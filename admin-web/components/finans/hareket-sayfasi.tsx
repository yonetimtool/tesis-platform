"use client";

// (P167 Asama 4) FINANSAL ISLEM SAYFASI — sekiz sayfanin ORTAK kabugu.
//
// =====================================================================
// NEDEN ORTAK KABUK, NEDEN SEKIZ AYRI SAYFA
// =====================================================================
// Brief §4: "Her biri AYRI sayfa... Hepsinde: liste (DataTable ile), sag
// ustte '+ Yeni' dugmesi, modal form, duzenle/sil eylemleri, Excel/PDF
// disa aktarma."
//
// Yani sekiz sayfanin DIS ISKELETI ayni, ICI farkli. Iskeleti sekiz kez
// yazmak, sekiz yerde ayni disa aktarma dugmesini, ayni iptal onayini ve
// ayni bos durumu kopyalamak olurdu — ve biri duzeltildiginde otekiler
// unutulurdu. Bu bilesen ISKELETI tasir; her sayfa yalnizca KENDI
// sutunlarini ve KENDI formunu verir.
//
// TERSI DE YAPILMADI (tek sayfa + `tip` sorgusu): P154'te oyleydi ve
// brief bilerek geri aliyor. Her sayfanin farkli bir "+ Yeni" formu,
// farkli sutunlari ve bazilarinin ikinci bir TOPLU akisi var; tek sayfada
// yedi modal tutmak, sayfayi hangi suzgecte oldugunu bilen dev bir
// kosula cevirirdi.
//
// =====================================================================
// SILME YOK — IPTAL VAR
// =====================================================================
// Brief'in zorunlu ilkesi: "Finansal kayitlar SILINMEZ; iptal/ters kayit
// mekanizmasi kullanilir." Uc zaten oyle (`POST /finans/hareketler/{id}
// /iptal`, goc 0047 DELETE yetkisini GERI ALDI). Bu kabuk da "Sil"
// dugmesi CIZMEZ; cizdigi sey "Iptal et"tir ve onayda ne olacagini
// soyler: kayit KALIR, ters bir satir eklenir.

import { useState, type ReactNode } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Dugme,
  VeriTablosu,
  useOnay,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { agIstegi, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kurusToTL } from "@/lib/money";

export interface Hareket {
  id: string;
  tip: string;
  yon: string;
  tutar_kurus: number;
  tarih: string;
  kasa_ad: string | null;
  user_ad: string | null;
  belge_no: string | null;
  aciklama: string | null;
  durum: string;
  ters_kayit_id: string | null;
  virman_grup_id: string | null;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const BICIM_EXCEL = "excel" as const;
const BICIM_PDF = "pdf" as const;
const UZANTI_EXCEL = "xlsx";
const UZANTI_PDF = "pdf";
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const YOK_ISARETI = "—";

function ExcelIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true"
      fill="none" stroke="currentColor" strokeWidth="1.75"
      strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 10h18M9 4v16M13 13l4 4M17 13l-4 4" />
    </svg>
  );
}

function PdfIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true"
      fill="none" stroke="currentColor" strokeWidth="1.75"
      strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" />
      <path d="M14 3v5h5M9 14h1.5a1.25 1.25 0 0 1 0 2.5H9zM9 14v5M14 14v5h1a1.5 1.5 0 0 0 1.5-1.5v-2A1.5 1.5 0 0 0 15 14z" />
    </svg>
  );
}

/**
 * DISA AKTARMA — mevcut rapor motoruna baglanir, YENI UC ACILMAZ.
 *
 * Rapor motoru (P31) zaten `POST /raporlar/{kod}?bicim=excel|pdf` ile
 * dosya uretiyor ve ayni `RaporSonuc`tan hem tablo hem dosya cikiyor.
 * Sayfaya ozel bir disa aktarma ucu, AYNI rakamlari IKINCI bir yerden
 * hesaplamak olurdu — ekranla dosyanin bir gun ayrismasi ancak oyle
 * mumkun olur.
 */
export function DisaAktar({ kod }: { kod: string }) {
  const t = useT();
  const toast = useToast();
  const [calisan, setCalisan] = useState<string | null>(null);

  async function indir(bicim: "excel" | "pdf") {
    setCalisan(bicim);
    try {
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
      URL.revokeObjectURL(url);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("panoIndirilemedi"));
    } finally {
      setCalisan(null);
    }
  }

  const dugme = (
    bicim: "excel" | "pdf", etiket: string, renk: string, ikon: ReactNode,
  ) => (
    <button
      type="button"
      onClick={() => void indir(bicim)}
      disabled={calisan !== null}
      aria-label={etiket}
      title={etiket}
      className="odak-ic flex h-9 w-9 items-center justify-center rounded-lg transition disabled:opacity-50"
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

/** Bir finans hareketi listesi + arac cubugu. */
export function HareketSayfasi({
  baslikAnahtari,
  tip,
  raporKodu,
  ekSutunlar,
  araclar,
  yenile,
  cocuk,
}: {
  baslikAnahtari: SozlukAnahtari;
  /** Listenin `tip` suzgeci. Bos ise TUM hareketler. */
  tip: string;
  /** Excel/PDF icin rapor katalog kodu. */
  raporKodu: string;
  /** Sayfaya ozel ek sutunlar (orn. gider sayfasinda Firma). */
  ekSutunlar?: Kolon<Hareket>[];
  /** Sag ustteki dugmeler ("+ Yeni", "+ Toplu ..."). */
  araclar: ReactNode;
  /** Modal kapandiktan sonra listeyi tazelemek icin sayac. */
  yenile: number;
  /** Modallar — sayfa kendi formunu buraya koyar. */
  cocuk?: ReactNode;
}) {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const [durum, setDurum] = useState<TabloDurumu>({
    sayfa: 1, boy: 25, siraKolon: null, siraYonu: "artan",
  });

  const suzgec = tip ? `&tip=${encodeURIComponent(tip)}` : "";
  const anahtar =
    `/api/panel/finans-hareketler?limit=${durum.boy}` +
    `&offset=${(durum.sayfa - 1) * durum.boy}${suzgec}&_=${yenile}`;
  const { data, error, isLoading, mutate } = useSWR<{
    meta: { total: number };
    items: Hareket[];
  }>(anahtar, jsonFetcher);

  async function iptalEt(h: Hareket) {
    // ONAY METNI NE OLACAGINI SOYLER: "sil" demek yanlis olurdu, kayit
    // kalir ve TERS bir satir eklenir. Kullanici defterde iki satir
    // gorecegini bilerek onaylamali.
    const ok = await onayla({
      baslik: t("finansIptalBaslik"),
      mesaj: t("finansIptalOnay", {
        belge: h.belge_no ?? YOK_ISARETI,
        tutar: kurusToTL(h.tutar_kurus),
      }),
      onayMetni: t("finansIptalEt"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(`/api/panel/finans-hareketler/${h.id}/iptal`, "POST", {});
      toast.success(t("finansIptalEdildi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const sutunlar: Kolon<Hareket>[] = [
    {
      id: "tarih",
      baslik: t("finansSutunTarih"),
      hucre: (h) => h.tarih,
      deger: (h) => h.tarih,
    },
    {
      id: "belge_no",
      baslik: t("finansSutunBelgeNo"),
      hucre: (h) => h.belge_no ?? YOK_ISARETI,
      deger: (h) => h.belge_no ?? "",
    },
    ...(ekSutunlar ?? []),
    {
      id: "tutar",
      baslik: t("finansSutunTutar"),
      hucre: (h) => (
        <span className="tabular-nums">{kurusToTL(h.tutar_kurus)}</span>
      ),
      deger: (h) => h.tutar_kurus,
      sayisal: true,
    },
    {
      id: "durum",
      baslik: t("finansSutunDurum"),
      // BILINMEYEN DURUM `odendi` SAYILMAZ, ham deger yazilir: sunucu bir
      // gun yeni bir durum eklerse onu "odendi" diye gostermek, defterde
      // olmayan bir gercegi iddia etmek olurdu.
      hucre: (h) => {
        const a = DURUM_ANAHTARI[h.durum];
        return a ? t(a) : h.durum;
      },
      deger: (h) => h.durum,
    },
    {
      id: "aciklama",
      baslik: t("finansSutunAciklama"),
      hucre: (h) => h.aciklama ?? YOK_ISARETI,
    },
    {
      id: "eylem",
      baslik: t("finansSutunEylem"),
      hucre: (h) =>
        // TERS KAYDIN KENDISI IPTAL EDILEMEZ (uc 422 doner) ve zaten
        // iptal edilmis bir kayit da ikinci kez iptal edilemez (409).
        // Dugmeyi cizip sunucuya reddettirmek, kullaniciya
        // yapamayacagi bir eylem gostermek olurdu.
        h.tip === TIP_IPTAL ? (
          <span style={{ color: "var(--yz-text-3)" }}>{YOK_ISARETI}</span>
        ) : (
          <Dugme tur="sessiz" boy="kucuk" onClick={() => void iptalEt(h)}>
            {t("finansIptalEt")}
          </Dugme>
        ),
    },
  ];

  return (
    <div className="space-y-4">
      {diyalog}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t(baslikAnahtari)}
        </h1>
        <div className="flex flex-wrap items-center gap-2">
          {araclar}
          <DisaAktar kod={raporKodu} />
        </div>
      </div>

      <VeriTablosu
        kolonlar={sutunlar}
        satirlar={data?.items ?? []}
        satirId={(h) => h.id}
        yukleniyor={isLoading}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={durum}
        onDurumDegisti={setDurum}
        bosBaslik={t("finansKayitYok")}
        // HATA TABLONUN ICINDE: disarida `HataDurumu` cizip tabloyu
        // altinda birakmak, ayni ekranda hem "cekilemedi" hem "kayit
        // yok" gostermek olurdu — ikincisi bir IDDIADIR ve yanlis
        // (kayit olabilir de, bilmiyoruz).
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
      />

      {cocuk}
    </div>
  );
}

// UCLUDE DIZE YAZILMAZ.
const TIP_IPTAL = "iptal";

/** Hareket durumu -> sozluk anahtari. */
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  odendi: "finansDurumOdendi",
  bekliyor: "finansDurumBekliyor",
  onay_bekliyor: "finansDurumOnayBekliyor",
};
