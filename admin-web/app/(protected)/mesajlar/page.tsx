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
  btnGhost,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
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

  return (
    <div className="space-y-6">
      <PageHeader title={t("mesajBaslik")} subtitle={t("mesajAlt")} />
      {/* (P154 / Asama 7.4) Sablon yoksa gonderim YAPILAMAZ
          (`POST /mesajlar/gonder`, envanter §0.4). */}
      <BagimlilikUyarisi
        kod="mesajSablonu"
        eksik={(sablonlar?.items.length ?? 1) === 0}
      />
      <ErrorBox message={hata ?? (sErr ? t("mesajSablonHata") : null)} />

      {/* ----------------------------- sablonlar --------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("mesajSablonlar")}</h2>
        {sablonlar && sablonlar.items.length === 0 ? (
          <EmptyState title={t("mesajSablonYok")} description={t("mesajSablonYokAlt")} />
        ) : null}
        {sablonlar && sablonlar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("mesajKanal")}</Th>
                  <Th sik>{t("mesajAd")}</Th>
                  <Th sik>{t("mesajAmac")}</Th>
                  <Th sik />
                </TabloBasligi>
              <tbody>
                {sablonlar.items.map((s) => (
                  <tr key={s.id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik>{t(`mesajKanal_${s.kanal}` as never)}</Td>
                    <Td sik>{s.ad}</Td>
                    <Td sik>
                      {/* AMAC SABLONDA (P32): ayni sablonun bir gun pazarlama
                          bir gun operasyonel gonderilmesi riza denetimini
                          anlamsiz kilardi — bu yuzden gonderimde secilemez. */}
                      {t(`mesajAmac_${s.amac}` as never)}
                    </Td>
                    <Td sik hizala="end">
                      <button className={btnDanger} onClick={() => sablonSil(s.id)}>
                        {t("ortakSil")}
                      </button>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
          </div>
        ) : null}
      </motion.section>

      {/* ---------------------------- yeni sablon -------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("mesajYeniSablon")}</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Field label={t("mesajKanal")}>
            <select className={inputCls} value={kanal} onChange={(e) => setKanal(e.target.value as Kanal)}>
              <option value="sms">{t("mesajKanal_sms")}</option>
              <option value="eposta">{t("mesajKanal_eposta")}</option>
            </select>
          </Field>
          <Field label={t("mesajAd")}>
            <input className={inputCls} value={ad} onChange={(e) => setAd(e.target.value)} />
          </Field>
          <Field label={t("mesajAmac")}>
            <select className={inputCls} value={amac} onChange={(e) => setAmac(e.target.value)}>
              <option value="operasyonel">{t("mesajAmac_operasyonel")}</option>
              <option value="pazarlama">{t("mesajAmac_pazarlama")}</option>
            </select>
          </Field>
          {kanal === "eposta" ? (
            <Field label={t("mesajKonu")}>
              <input className={inputCls} value={konu} onChange={(e) => setKonu(e.target.value)} />
            </Field>
          ) : null}
        </div>
        <Field label={t("mesajGovde")}>
          <textarea
            className={`${inputCls} min-h-24`}
            value={govde}
            onChange={(e) => setGovde(e.target.value)}
          />
        </Field>
        <p className="mt-1 text-xs text-metin-muted">{t("mesajEtiketIpucu")}</p>
        <button className={`${btnPrimary} mt-3`} disabled={mesgul} onClick={sablonEkle}>
          {t("mesajSablonKaydet")}
        </button>
      </motion.section>

      {/* --------------------------- onizleme ------------------------------ */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("mesajOnizleme")}</h2>
        <div className="flex flex-wrap items-end gap-3">
          <Field label={t("mesajSablon")}>
            <select
              className={inputCls}
              value={seciliId}
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
              ))}
            </select>
          </Field>
          <button className={btnGhost} disabled={mesgul || !seciliId} onClick={onizle}>
            {t("mesajOnizle")}
          </button>
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
      </motion.section>

      {/* ------------------------------ gecmis ----------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("mesajGecmis")}</h2>
        <ErrorBox message={gErr ? t("mesajGecmisHata") : null} />
        {gecmis && gecmis.items.length === 0 && !gErr ? (
          <EmptyState title={t("mesajGecmisYok")} description={t("mesajGecmisYokAlt")} />
        ) : null}
        {gecmis && gecmis.items.length > 0 ? (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("mesajTarih")}</Th>
                  <Th sik>{t("mesajKanal")}</Th>
                  <Th sik>{t("mesajHedef")}</Th>
                  <Th sik>{t("mesajDurum")}</Th>
                </TabloBasligi>
              <tbody>
                {gecmis.items.map((g) => (
                  <tr key={g.id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik className="whitespace-nowrap">{formatDateTime(g.created_at)}</Td>
                    <Td sik>{t(`mesajKanal_${g.kanal}` as never)}</Td>
                    <Td sik>{g.hedef}</Td>
                    <Td sik>
                      {t(`mesajDurum_${g.durum}` as never)}
                      {g.hata ? <span className="ms-1 text-rose-600">· {g.hata}</span> : null}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
          </div>
        ) : null}
        <button className={`${btnGhost} mt-3`} onClick={() => gecmisTazele()}>
          {t("ortakYenile")}
        </button>
      </motion.section>
    </div>
  );
}
