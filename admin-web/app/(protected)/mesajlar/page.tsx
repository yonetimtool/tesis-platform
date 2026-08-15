"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  CokSatir,
  Kart,
  VeriTablosu,
  type Kolon,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { useT } from "@/lib/i18n/kullan";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/** Sablon kanallari — veritabanindaki `mesaj_kanal` enum'uyla AYNI.
 *
 * WHATSAPP BURADA YOK ve bu bilincli: enum bugun yalnizca `sms, eposta`
 * tasiyor. Secenegi eklemek, kaydedilemeyen bir sablon formu acmak
 * olurdu. WhatsApp Asama 9'un kalan isidir (enum + sablon onay alanlari,
 * bkz. docs/whatsapp-arastirma.md).
 */
type Kanal = "sms" | "eposta";
const KANALLAR: readonly Kanal[] = ["sms", "eposta"];

/**
 * P40 — MESAJ bolumu (P32 API'si).
 *
 * SMS SAYACI EKRANDA: Turkce harf tuzagi (kucuk i-noktasiz, g-yumusak ve
 * s-cedilla GSM-7'de YOKTUR) mesaji UCS-2'ye dusurur ve 160 karakterlik
 * sinir 70'e iner — "biraz uzun" bir
 * mesaj birden UC SMS olur. Sayaci gizlemek, kullanicinin faturayi
 * gonderdikten SONRA gormesi demekti; bu yuzden onizleme ucu cagrilir ve
 * parca sayisi ile ZORLAYAN karakterler gosterilir.
 *
 * RIZA GONDERIMDE ZORLANIR (P36): pazarlama sablonu yalniz O KANALA izin
 * vermis kisilere gider; atlananlar SESSIZCE DUSURULMEZ, sayilir.
 */

interface Sablon {
  id: string;
  kanal: string;
  ad: string;
  konu: string | null;
  govde: string;
  amac: string;
  aktif: boolean;
}
interface Gecmis {
  id: string;
  kanal: string;
  amac: string;
  hedef: string;
  konu: string | null;
  durum: string;
  hata: string | null;
  created_at: string;
}
interface Onizleme {
  konu: string | null;
  govde: string;
  karakter: number;
  unicode_mi: boolean;
  parca: number;
  kalan: number;
  zorlayan: string[];
}

const LIMIT = 20;

export default function MesajlarPage() {
  const t = useT();
  const toast = useToast();

  const {
    data: sablonlar,
    error: sErr,
    mutate: sablonTazele,
  } = useSWR<{ items: Sablon[] }>("/api/panel/mesaj-sablonlari?limit=100", jsonFetcher);
  const { data: gecmis, error: gErr, mutate: gecmisTazele } = useSWR<{ items: Gecmis[] }>(
    `/api/panel/mesaj-gecmis?limit=${LIMIT}`,
    jsonFetcher,
  );

  // --- yeni sablon ---
  // (P154 / Asama 7.1) Menudeki "SMS gonderimi / WhatsApp / E-posta
  // gonderimi" satirlari uc ayri sayfa DEGIL, bu secimin on ayarlari.
  const [kanal, setKanal] = useSorguSecimi<Kanal>("kanal", KANALLAR, "sms");
  const [ad, setAd] = useState("");
  const [konu, setKonu] = useState("");
  const [govde, setGovde] = useState("");
  const [amac, setAmac] = useState("operasyonel");
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);

  // --- onizleme + gonderim ---
  const [seciliId, setSeciliId] = useState("");
  const [onizleme, setOnizleme] = useState<Onizleme | null>(null);
  const [sonuc, setSonuc] = useState<Record<string, number> | null>(null);

  async function sablonEkle(): Promise<void> {
    setHata(null);
    if (!ad.trim() || !govde.trim()) {
      setHata(t("mesajAdGovdeGerekli"));
      return;
    }
    setMesgul(true);
    try {
      await apiSend("/api/panel/mesaj-sablonlari", "POST", {
        kanal,
        ad,
        konu: kanal === "eposta" ? konu || null : null,
        govde,
        amac,
      });
      setAd("");
      setGovde("");
      setKonu("");
      toast.success(t("mesajSablonEklendi"));
      await sablonTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  async function sablonSil(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/mesaj-sablonlari/${id}`, "DELETE");
      toast.success(t("mesajSablonSilindi"));
      await sablonTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  async function onizle(): Promise<void> {
    setHata(null);
    setSonuc(null);
    if (!seciliId) return;
    setMesgul(true);
    try {
      const veri = (await apiSend("/api/panel/mesaj-onizleme", "POST", {
        sablon_id: seciliId,
      })) as Onizleme;
      setOnizleme(veri);
    } catch (e) {
      setOnizleme(null);
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  const gecmisKolonlari: Kolon<Gecmis>[] = useMemo(
    () => [
      {
        id: "tarih",
        baslik: t("mesajTarih"),
        gizlenebilir: false,
        hucre: (g) => <span className="whitespace-nowrap">{formatDateTime(g.created_at)}</span>,
      },
      {
        id: "kanal",
        baslik: t("mesajKanal"),
        hucre: (g) => t(`mesajKanal_${g.kanal}` as never),
      },
      { id: "hedef", baslik: t("mesajHedef"), hucre: (g) => g.hedef },
      {
        id: "durum",
        baslik: t("mesajDurum"),
        hucre: (g) => (
          <>
            {t(`mesajDurum_${g.durum}` as never)}
            {/* SEBEP GORUNUR KALIR: "basarisiz" tek basina ne yapilacagini
                soylemiyor; saglayici hatasi burada yaziyor. */}
            {g.hata ? (
              <span className="ms-1" style={{ color: "var(--yz-danger-ink)" }}>
                · {g.hata}
              </span>
            ) : null}
          </>
        ),
      },
    ],
    [t],
  );

  const sablonKolonlari: Kolon<Sablon>[] = useMemo(
    () => [
      {
        id: "kanal",
        baslik: t("mesajKanal"),
        gizlenebilir: false,
        hucre: (s) => t(`mesajKanal_${s.kanal}` as never),
      },
      { id: "ad", baslik: t("mesajAd"), hucre: (s) => s.ad },
      {
        id: "amac",
        baslik: t("mesajAmac"),
        // AMAC SABLONDA (P32): ayni sablonun bir gun pazarlama bir gun
        // operasyonel gonderilmesi riza denetimini anlamsiz kilardi — bu
        // yuzden gonderimde secilemez.
        hucre: (s) => t(`mesajAmac_${s.amac}` as never),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (s) => (
          <div className="flex justify-end">
            <Dugme tur="tehlike" boy="kucuk" onClick={() => void sablonSil(s.id)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-6">
      <div>
        <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("mesajBaslik")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => setModalAcik(true)}>
          {t("mesajYeniSablon")}
        </Dugme>
      </div>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("mesajAlt")}</p>
      </div>
      {/* (P154 / Asama 7.4) Sablon yoksa gonderim YAPILAMAZ
          (`POST /mesajlar/gonder`, envanter §0.4). */}
      <BagimlilikUyarisi
        kod="mesajSablonu"
        eksik={(sablonlar?.items.length ?? 1) === 0}
      />
      <HataDurumu mesaj={hata ?? (sErr ? t("mesajSablonHata") : null)} />

      {/* ----------------------------- sablonlar --------------------------- */}
      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("mesajSablonlar")}
        </h2>
        <VeriTablosu<Sablon>
          kolonlar={sablonKolonlari}
          satirlar={sablonlar?.items ?? []}
          satirId={(s) => s.id}
          hata={sErr ? t("mesajSablonHata") : null}
          yukleniyor={!sablonlar && !sErr}
          bosBaslik={t("mesajSablonYok")}
          bosAciklama={t("mesajSablonYokAlt")}
        />
      </section>

      {/* ---------------------------- yeni sablon -------------------------- */}
      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("mesajYeniSablon")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={mesgul}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={mesgul} onClick={sablonEkle}>
          {t("mesajSablonKaydet")}
        </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <AlanSarmal etiket={t("mesajKanal")}>
  {(b) => (
    <Secim {...b} value={kanal} onChange={(e) => setKanal(e.target.value as Kanal)}>
              <option value="sms">{t("mesajKanal_sms")}</option>
              <option value="eposta">{t("mesajKanal_eposta")}</option></Secim>
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("mesajAd")}>
  {(b) => (
    <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("mesajAmac")}>
  {(b) => (
    <Secim {...b} value={amac} onChange={(e) => setAmac(e.target.value)}>
              <option value="operasyonel">{t("mesajAmac_operasyonel")}</option>
              <option value="pazarlama">{t("mesajAmac_pazarlama")}</option></Secim>
  )}
</AlanSarmal>
          {kanal === "eposta" ? (
            <AlanSarmal etiket={t("mesajKonu")}>
  {(b) => (
    <Alan {...b} value={konu} onChange={(e) => setKonu(e.target.value)} />
  )}
</AlanSarmal>
          ) : null}
        </div>
        <AlanSarmal etiket={t("mesajGovde")}>
          {(b) => (
            <CokSatir
              {...b}
              rows={4}
              value={govde}
              onChange={(e) => setGovde(e.target.value)}
            />
          )}
        </AlanSarmal>
        <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("mesajEtiketIpucu")}</p>
        </div>
      </Modal>

      {/* --------------------------- onizleme ------------------------------ */}
      <Kart>
        <h2 className="mb-3 text-sm font-semibold">{t("mesajOnizleme")}</h2>
        <div className="flex flex-wrap items-end gap-3">
          <AlanSarmal etiket={t("mesajSablon")}>
  {(b) => (
    <Secim {...b} value={seciliId}
              onChange={(e) => {
                setSeciliId(e.target.value);
                setOnizleme(null);
              }}
            >
              <option value="">—</option>
              {(sablonlar?.items ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.ad}
                </option>
              ))}</Secim>
  )}
</AlanSarmal>
          <Dugme boy="kucuk" disabled={mesgul || !seciliId} onClick={onizle}>
            {t("mesajOnizle")}
          </Dugme>
        </div>
        {onizleme ? (
          <div className="mt-3 space-y-2">
            <pre className="whitespace-pre-wrap rounded bg-yuzey-bg p-3 text-xs dark:bg-slate-800">
              {onizleme.govde}
            </pre>
            <div className="text-xs text-metin-body dark:text-slate-400">
              {t("mesajSayacKarakter")}: <b className="tabular-nums">{onizleme.karakter}</b> ·{" "}
              {t("mesajSayacParca")}: <b className="tabular-nums">{onizleme.parca}</b> ·{" "}
              {t("mesajSayacKalan")}: <b className="tabular-nums">{onizleme.kalan}</b>
            </div>
            {onizleme.unicode_mi ? (
              // ZORLAYAN KARAKTERLER GOSTERILIR: "neden 3 SMS oldu" sorusunu
              // kullanicinin metne bakip tahmin etmesine birakmak, sayaci
              // yarim gostermek olurdu.
              <div className="rounded bg-amber-50 p-2 text-xs text-amber-900 dark:bg-amber-950 dark:text-amber-200">
                {t("mesajUnicodeUyari")} <b>{onizleme.zorlayan.join(" ")}</b>
              </div>
            ) : null}
          </div>
        ) : null}
        {sonuc ? (
          <div className="mt-3 text-xs text-metin-body dark:text-slate-400">
            {t("mesajSonucGonderildi")}: {sonuc.gonderildi} · {t("mesajSonucRizaYok")}:{" "}
            {sonuc.riza_yok} · {t("mesajSonucAdresYok")}: {sonuc.adres_yok} ·{" "}
            {t("mesajSonucBasarisiz")}: {sonuc.basarisiz}
          </div>
        ) : null}
      </Kart>

      {/* ------------------------------ gecmis ----------------------------- */}
      <section className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("mesajGecmis")}
          </h2>
          <Dugme boy="kucuk" onClick={() => void gecmisTazele()}>
            {t("ortakYenile")}
          </Dugme>
        </div>
        <VeriTablosu<Gecmis>
          kolonlar={gecmisKolonlari}
          satirlar={gecmis?.items ?? []}
          satirId={(g) => g.id}
          hata={gErr ? t("mesajGecmisHata") : null}
          onTekrar={() => void gecmisTazele()}
          yukleniyor={!gecmis && !gErr}
          bosBaslik={t("mesajGecmisYok")}
          bosAciklama={t("mesajGecmisYokAlt")}
        />
      </section>
    </div>
  );
}
