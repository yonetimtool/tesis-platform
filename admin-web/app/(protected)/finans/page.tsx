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
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";

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

export default function FinansPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [tip, setTip] = useState("");

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
      });
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
            <table className="w-full text-sm">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("finansKasaKod")}</th>
                  <th className="px-3 py-2">{t("finansKasaAd")}</th>
                  <th className="px-3 py-2 text-right">{t("finansBakiye")}</th>
                </tr>
              </thead>
              <tbody>
                {kasalar.items.map((k) => (
                  <tr key={k.kasa_id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="px-3 py-2 font-mono text-xs">{k.kod}</td>
                    <td className="px-3 py-2">{k.ad}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{kurusToTL(k.bakiye_kurus)}</td>
                  </tr>
                ))}
                <tr className="border-t-2 border-slate-200 font-semibold dark:border-slate-700">
                  <td className="px-3 py-2" colSpan={2}>
                    {t("finansGenelToplam")}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {kurusToTL(kasalar.genel_toplam_kurus)}
                  </td>
                </tr>
              </tbody>
            </table>
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
          <select
            className={inputCls}
            style={{ maxWidth: 200 }}
            value={tip}
            onChange={(e) => {
              setTip(e.target.value);
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
              <table className="w-full text-sm">
                <thead className="text-left text-slate-500">
                  <tr>
                    <th className="px-3 py-2">{t("finansTarih")}</th>
                    <th className="px-3 py-2">{t("finansTip")}</th>
                    <th className="px-3 py-2">{t("finansKasa")}</th>
                    <th className="px-3 py-2">{t("finansKisi")}</th>
                    <th className="px-3 py-2">{t("finansAciklama")}</th>
                    <th className="px-3 py-2 text-right">{t("finansTutar")}</th>
                  </tr>
                </thead>
                <tbody>
                  {hareketler.items.map((h) => (
                    <tr key={h.id} className="border-t border-slate-100 dark:border-slate-800">
                      <td className="px-3 py-2 whitespace-nowrap">{formatDateTime(h.tarih)}</td>
                      <td className="px-3 py-2">{t(`finansTip_${h.tip}` as never)}</td>
                      <td className="px-3 py-2">{h.kasa_ad ?? "—"}</td>
                      <td className="px-3 py-2">{h.user_ad ?? "—"}</td>
                      <td className="px-3 py-2">{h.aciklama ?? h.belge_no ?? "—"}</td>
                      {/* YON RENGI: tutar her zaman POZITIFTIR (P29); giris/cikis
                          ayrimi isaretle degil `yon` alaniyla anlatilir. */}
                      <td
                        className={`px-3 py-2 text-right tabular-nums ${
                          h.yon === "giris" ? "text-emerald-600" : "text-rose-600"
                        }`}
                      >
                        {h.yon === "giris" ? "+" : "−"}
                        {kurusToTL(h.tutar_kurus)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
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
      <div className="text-xs text-slate-500">{etiket}</div>
      <div className="mt-1 text-lg font-semibold tabular-nums">{deger}</div>
    </div>
  );
}
