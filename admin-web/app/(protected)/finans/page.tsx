"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  Pager,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/**
 * P40 — FINANS bolumu (P29 API'si).
 *
 * NEDEN OZET + KASA + HAREKET AYNI SAYFADA: bunlar tek bir soruyu
 * yanitlar — "para nerede ve bugun ne oldu". Ayri sayfalara bolmek,
 * kullaniciyi ayni sorunun parcalari arasinda gezdirirdi.
 *
 * BAKIYE SAKLANMAZ, DEFTERDEN TURETILIR (P29 karari): bu sayfa da bakiyeyi
 * hicbir yerde kendisi hesaplamaz — `/finans/kasa-bakiyeleri` ne diyorsa
 * onu cizer. Istemcide toplam almak, iki yerde iki farkli rakam demekti.
 */

interface KasaBakiye {
  kasa_id: string;
  kod: string;
  ad: string;
  bakiye_kurus: number;
}
interface Hareket {
  id: string;
  tip: string;
  yon: string;
  tutar_kurus: number;
  tarih: string;
  kasa_ad: string | null;
  user_ad: string | null;
  belge_no: string | null;
  aciklama: string | null;
}
interface Ozet {
  borclandirilan_ay_kurus: number;
  tahsil_edilen_ay_kurus: number;
  acik_borc_kurus: number;
  kasa_toplam_kurus: number;
  icra_acik_dosya: number;
}

const LIMIT = 20;
const TIPLER = ["tahsilat", "gider", "gelir", "virman", "iade", "acilis"] as const;
/** Suzgec degeri: alti tipten biri ya da "" (hepsi). */
type TipSecimi = "" | (typeof TIPLER)[number];

export default function FinansPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  // (P154 / Asama 7.1) Menuden gelen `?tip=gelir` gibi baglantilar
  // burada karsilanir; okunmasaydi menu satiri dogru adrese gider ama
  // sayfa tum hareketleri gosterirdi.
  const [tip, setTip] = useSorguSecimi<TipSecimi>("tip", TIPLER, "");

  const suzgec = tip ? `&tip=${encodeURIComponent(tip)}` : "";
  const { data: ozet, error: ozetErr } = useSWR<Ozet>(
    "/api/panel/finans-ozet",
    jsonFetcher,
  );
  const { data: kasalar, error: kasaErr } = useSWR<{ items: KasaBakiye[]; genel_toplam_kurus: number }>(
    "/api/panel/kasa-bakiyeleri",
    jsonFetcher,
  );
  const {
    data: hareketler,
    error: harErr,
    mutate: hareketleriTazele,
  } = useSWR<{ items: Hareket[]; meta: { total: number } }>(
    `/api/panel/finans-hareketler?limit=${LIMIT}&offset=${offset}${suzgec}`,
    jsonFetcher,
  );

  // --- yeni hareket ---
  const [yTip, setYTip] = useState<string>("gider");
  const [yTutar, setYTutar] = useState("");
  const [yKasa, setYKasa] = useState("");
  const [yTarih, setYTarih] = useState("");
  const [yAciklama, setYAciklama] = useState("");
  const [yHata, setYHata] = useState<string | null>(null);
  const [ymesgul, setYMesgul] = useState(false);
  // (P64) CIFT KAYIT KORUMASI. Dugmenin `ymesgul` kilidi yalniz HIZLI CIFT
  // TIKLAMAYI onler; korunmayan sey ZAMAN ASIMI SONRASI TEKRARDI — istek
  // sunucuya ulasip yanit donmezse kullanici "kaydedilmedi" sanip tekrar
  // basar ve kasada IKI hareket olusurdu. Anahtar FORM DOLDURMA ANINDA
  // uretilir ve BASARIYA KADAR sabit kalir: tekrar denemeler ayni anahtarla
  // gider, sunucu ikinci kaydi acmaz. Basarinin ardindan yenilenir ki
  // SONRAKI (mesru) hareket ayri bir islem sayilsin.
  const [yAnahtar, setYAnahtar] = useState(() => genIdempotencyKey());

  async function hareketEkle(): Promise<void> {
    setYHata(null);
    const kurus = tlToKurus(yTutar);
    if (!kurus || kurus <= 0) {
      setYHata(t("finansTutarGerekli"));
      return;
    }
    setYMesgul(true);
    try {
      // Toplu uc TEK KAYIT icin de kullanilir: iki ayri uc, ayni
      // dogrulamayi iki kez yazmak olurdu (P29 karari).
      await apiSend("/api/panel/finans-hareketler", "POST", {
        hareketler: [
          {
            tip: yTip,
            tutar_kurus: kurus,
            kasa_id: yKasa || null,
            tarih: yTarih || undefined,
            aciklama: yAciklama || null,
          },
        ],
      }, { "Idempotency-Key": yAnahtar });
      setYAnahtar(genIdempotencyKey());
      setYTutar("");
      setYAciklama("");
      toast.success(t("finansHareketEklendi"));
      await hareketleriTazele();
    } catch (e) {
      setYHata(e instanceof Error ? e.message : String(e));
    } finally {
      setYMesgul(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("finansBaslik")} subtitle={t("finansAlt")} />

      {/* ------------------------------- ozet ------------------------------ */}
      <ErrorBox message={ozetErr ? t("finansOzetHata") : null} />
      {ozet ? (
        <motion.div {...panelMotion} className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <OzetKart etiket={t("finansOzetBorclandirilan")} deger={kurusToTL(ozet.borclandirilan_ay_kurus)} />
          <OzetKart etiket={t("finansOzetTahsil")} deger={kurusToTL(ozet.tahsil_edilen_ay_kurus)} />
          <OzetKart etiket={t("finansOzetAcikBorc")} deger={kurusToTL(ozet.acik_borc_kurus)} />
          <OzetKart etiket={t("finansOzetKasa")} deger={kurusToTL(ozet.kasa_toplam_kurus)} />
          <OzetKart etiket={t("finansOzetIcra")} deger={String(ozet.icra_acik_dosya)} />
        </motion.div>
      ) : null}

      {/* ------------------------------ kasalar ---------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("finansKasalar")}</h2>
        <ErrorBox message={kasaErr ? t("finansKasaHata") : null} />
        {kasalar && kasalar.items.length === 0 ? (
          <EmptyState title={t("finansKasaYok")} description={t("finansKasaYokAlt")} />
        ) : null}
        {kasalar && kasalar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("finansKasaKod")}</Th>
                  <Th sik>{t("finansKasaAd")}</Th>
                  <Th sik hizala="end">{t("finansBakiye")}</Th>
                </TabloBasligi>
              <tbody>
                {kasalar.items.map((k) => (
                  <tr key={k.kasa_id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik className="font-mono text-xs">{k.kod}</Td>
                    <Td sik>{k.ad}</Td>
                    <Td sik hizala="end" sayi>{kurusToTL(k.bakiye_kurus)}</Td>
                  </tr>
                ))}
                <tr className="border-t-2 kart-kenar font-semibold dark:border-slate-700">
                  <Td sik colSpan={2}>
                    {t("finansGenelToplam")}
                  </Td>
                  <Td sik hizala="end" sayi>
                    {kurusToTL(kasalar.genel_toplam_kurus)}
                  </Td>
                </tr>
              </tbody>
            </Tablo>
          </div>
        ) : null}
      </motion.section>

      {/* --------------------------- yeni hareket -------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("finansYeniHareket")}</h2>
        <ErrorBox message={yHata} />
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Field label={t("finansTip")}>
            <select className={inputCls} value={yTip} onChange={(e) => setYTip(e.target.value)}>
              {TIPLER.map((x) => (
                <option key={x} value={x}>
                  {t(`finansTip_${x}` as never)}
                </option>
              ))}
            </select>
          </Field>
          <Field label={t("finansTutar")}>
            <input
              className={inputCls}
              inputMode="decimal"
              value={yTutar}
              onChange={(e) => setYTutar(e.target.value)}
            />
          </Field>
          <Field label={t("finansKasa")}>
            <select className={inputCls} value={yKasa} onChange={(e) => setYKasa(e.target.value)}>
              <option value="">—</option>
              {(kasalar?.items ?? []).map((k) => (
                <option key={k.kasa_id} value={k.kasa_id}>
                  {k.ad}
                </option>
              ))}
            </select>
          </Field>
          <Field label={t("finansTarih")}>
            <input
              className={inputCls}
              type="date"
              value={yTarih}
              onChange={(e) => setYTarih(e.target.value)}
            />
          </Field>
          <Field label={t("finansAciklama")}>
            <input
              className={inputCls}
              value={yAciklama}
              onChange={(e) => setYAciklama(e.target.value)}
            />
          </Field>
        </div>
        <button className={`${btnPrimary} mt-3`} disabled={ymesgul} onClick={hareketEkle}>
          {t("finansEkle")}
        </button>
      </motion.section>

      {/* ----------------------------- hareketler -------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 className="text-sm font-semibold">{t("finansHareketler")}</h2>
          {/* (P63) Suzgecin HICBIR etiketi yoktu: ekran okuyucu yalnizca
              "acilir liste" der ve kullanici neyi suzdugunu bilmez. */}
          <select
            aria-label={t("finansTipSuzgeci")}
            className={inputCls}
            style={{ maxWidth: 200 }}
            value={tip}
            onChange={(e) => {
              setTip(e.target.value as TipSecimi);
              setOffset(0);
            }}
          >
            <option value="">{t("finansHepsi")}</option>
            {TIPLER.map((x) => (
              <option key={x} value={x}>
                {t(`finansTip_${x}` as never)}
              </option>
            ))}
          </select>
        </div>
        {/* HATA SESSIZ KALMAZ: uc dustugunde "kayit yok" gostermek,
            kullaniciya kasanin bos oldugunu soylemek olurdu. */}
        <ErrorBox message={harErr ? t("finansHareketHata") : null} />
        {hareketler && hareketler.items.length === 0 && !harErr ? (
          <EmptyState title={t("finansHareketYok")} description={t("finansHareketYokAlt")} />
        ) : null}
        {hareketler && hareketler.items.length > 0 ? (
          <>
            <div className="overflow-x-auto">
              <Tablo>
                <TabloBasligi zeminsiz>
                    <Th sik>{t("finansTarih")}</Th>
                    <Th sik>{t("finansTip")}</Th>
                    <Th sik>{t("finansKasa")}</Th>
                    <Th sik>{t("finansKisi")}</Th>
                    <Th sik>{t("finansAciklama")}</Th>
                    <Th sik hizala="end">{t("finansTutar")}</Th>
                  </TabloBasligi>
                <tbody>
                  {hareketler.items.map((h) => (
                    <tr key={h.id} className="border-t border-yuzey-divider dark:border-slate-800">
                      <Td sik className="whitespace-nowrap">{formatDateTime(h.tarih)}</Td>
                      <Td sik>{t(`finansTip_${h.tip}` as never)}</Td>
                      <Td sik>{h.kasa_ad ?? "—"}</Td>
                      <Td sik>{h.user_ad ?? "—"}</Td>
                      <Td sik>{h.aciklama ?? h.belge_no ?? "—"}</Td>
                      {/* YON RENGI: tutar her zaman POZITIFTIR (P29); giris/cikis
                          ayrimi isaretle degil `yon` alaniyla anlatilir. */}
                      <Td className={`px-3 py-2 text-end tabular-nums ${
                          h.yon === "giris" ? "text-emerald-600" : "text-rose-600"
                        }`}>
                        {h.yon === "giris" ? "+" : "−"}
                        {kurusToTL(h.tutar_kurus)}
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </Tablo>
            </div>
            <Pager
              offset={offset}
              limit={LIMIT}
              total={hareketler.meta.total}
              onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
              onNext={() => setOffset(offset + LIMIT)}
            />
          </>
        ) : null}
      </motion.section>
    </div>
  );
}

function OzetKart({ etiket, deger }: { etiket: string; deger: string }) {
  return (
    <div className={`${panelCls} !p-4`}>
      <div className="text-xs text-metin-muted">{etiket}</div>
      <div className="mt-1 text-lg font-semibold tabular-nums">{deger}</div>
    </div>
  );
}
