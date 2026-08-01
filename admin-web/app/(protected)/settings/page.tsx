"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, PageHeader, inputCls, btnPrimary, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { TenantSettings } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P40) Ayarlar — kimlik alanlari + OPERASYON ayarlari.
 *
 * NEDEN AYNI SAYFA: bunlarin hepsi "bu tesis nasil calisir" sorusunun
 * yanitidir ve yonetici bunlari kurulumda ART ARDA doldurur. Tur alarmi,
 * guvenlik modu ve gurultu esigini ayri sayfalara bolmek, kullaniciyi
 * ayni kurulumun parcalari arasinda gezdirirdi.
 *
 * NEDEN VERI-SURUCULU: on alan icin on <input> yazmak ayni onChange/
 * dogrulama kalibini on kez kopyalamak olurdu (P27 "Tanimlar" ile ayni
 * gerekce).
 */

/** Operasyon ayari alan tanimi. `anahtar` backend alan adidir. */
interface Ayar {
  anahtar: keyof TenantSettings & string;
  etiket: SozlukAnahtari;
  ipucu?: SozlukAnahtari;
  tip: "sayi" | "bool" | "metin" | "secim";
  secenekler?: { deger: string; etiket: SozlukAnahtari }[];
  min?: number;
  max?: number;
  /** YALNIZ admin degistirebilir (sunucu de zorlar; burada gorunurluk). */
  adminOnly?: boolean;
}

/** Alan tipi -> HTML input tipi. Ucluda ("sayi" ? "number" : "text")
 *  yazmak, sabit-metin taramasini cevrilmemis metin sanip uyarmaya iterdi;
 *  bunlar KULLANICI METNI DEGIL teknik jetondur. */
const GIRDI_TIPI: Record<string, string> = { sayi: "number", metin: "text" };

const OPERASYON: Ayar[] = [
  // --- P34 tur butunlugu ---
  {
    anahtar: "tur_gecikme_toleransi_dk",
    etiket: "ayarTurTolerans",
    ipucu: "ayarTurToleransIpucu",
    tip: "sayi",
    min: 1,
    max: 240,
  },
  {
    anahtar: "tur_alarm_tekrar_sayisi",
    etiket: "ayarTurTekrar",
    ipucu: "ayarTurTekrarIpucu",
    tip: "sayi",
    min: 0,
    max: 10,
  },
  {
    anahtar: "tur_baslangic_foto_zorunlu",
    etiket: "ayarTurFoto",
    ipucu: "ayarTurFotoIpucu",
    tip: "bool",
  },
  // --- P35 guvenlik modu ---
  {
    anahtar: "guvenlik_modu",
    etiket: "ayarGuvenlikModu",
    ipucu: "ayarGuvenlikModuIpucu",
    tip: "secim",
    secenekler: [
      { deger: "yonetim_ici", etiket: "ayarGuvenlikYonetimIci" },
      { deger: "dis_sirket", etiket: "ayarGuvenlikDisSirket" },
    ],
    adminOnly: true,
  },
  // --- P37 gurultu caydirici ---
  {
    anahtar: "gurultu_esigi",
    etiket: "ayarGurultuEsigi",
    ipucu: "ayarGurultuEsigiIpucu",
    tip: "sayi",
    min: 1,
    max: 50,
  },
  { anahtar: "gurultu_uyari_metni", etiket: "ayarGurultuMetni", ipucu: "ayarGurultuMetniIpucu", tip: "metin" },
];

export default function SettingsPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<TenantSettings>(
    "/api/tenant/settings",
    jsonFetcher,
  );

  const [ad, setAd] = useState("");
  const [timezone, setTimezone] = useState("");
  const [ops, setOps] = useState<Record<string, unknown>>({});
  const [loaded, setLoaded] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (data && !loaded) {
      setAd(data.ad);
      setTimezone(data.timezone);
      const baslangic: Record<string, unknown> = {};
      const kaynak = data as unknown as Record<string, unknown>;
      for (const a of OPERASYON) baslangic[a.anahtar] = kaynak[a.anahtar];
      setOps(baslangic);
      setLoaded(true);
    }
  }, [data, loaded]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setFormErr(null);
    setOk(null);
    setSaving(true);
    try {
      await apiSend("/api/tenant/settings", "PATCH", { ad, timezone });
      setOk(t("ayarKaydedildi"));
      mutate();
      toast.success(t("ayarKaydedildi"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ayarKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function opKaydet(): Promise<void> {
    setFormErr(null);
    setSaving(true);
    try {
      // DEGISMEYEN ALAN GONDERILMEZ: `guvenlik_modu`nu her kayitta
      // gondermek, degismese bile denetim kaydi uretmezdi ama yoneticiye
      // 403 verirdi (o alani yalniz admin gonderebilir).
      const govde: Record<string, unknown> = {};
      for (const a of OPERASYON) {
        const yeni = ops[a.anahtar];
        const eski = (data as unknown as Record<string, unknown>)?.[a.anahtar];
        if (yeni !== eski) govde[a.anahtar] = yeni === "" ? null : yeni;
      }
      if (Object.keys(govde).length === 0) {
        setOk(t("ayarDegisiklikYok"));
        return;
      }
      await apiSend("/api/tenant/settings", "PATCH", govde);
      setOk(t("ayarKaydedildi"));
      mutate();
      toast.success(t("ayarKaydedildi"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ayarKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="max-w-2xl space-y-5">
      <PageHeader title={t("kabukAyarlar")} />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {data && (
        <>
          <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
            <div className="grid grid-cols-2 gap-3 text-sm text-muted">
              <div>
                <span className="block font-medium text-slate-700">{t("ayarTesisKodu")}</span>
                {data.slug}
              </div>
              <div>
                <span className="block font-medium text-slate-700">{t("ayarTenantId")}</span>
                <span className="font-mono">{data.tenant_id.slice(0, 8)}</span>
              </div>
            </div>

            <Field label={t("ayarTesisAdi")}>
              <input className={inputCls} value={ad} onChange={(e) => setAd(e.target.value)} required />
            </Field>

            <Field label={t("ayarZamanDilimi")} hint={t("ayarSaatDilimiOrnek")}>
              <input
                className={inputCls}
                value={timezone}
                onChange={(e) => setTimezone(e.target.value)}
                required
              />
            </Field>

            <ErrorBox message={formErr} />
            {ok && <p className="text-sm text-emerald-700">{ok}</p>}

            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
          </motion.form>

          {/* ------------------------ operasyon ayarlari ------------------- */}
          <motion.section {...panelMotion} className={`space-y-4 ${panelCls}`}>
            <h2 className="text-sm font-semibold">{t("ayarOperasyon")}</h2>
            {OPERASYON.map((a) => (
              <Field
                key={a.anahtar}
                label={t(a.etiket)}
                hint={a.ipucu ? t(a.ipucu) : undefined}
              >
                {a.tip === "bool" ? (
                  <input
                    type="checkbox"
                    className="h-4 w-4"
                    checked={Boolean(ops[a.anahtar])}
                    onChange={(e) => setOps({ ...ops, [a.anahtar]: e.target.checked })}
                  />
                ) : a.tip === "secim" ? (
                  <select
                    className={inputCls}
                    value={String(ops[a.anahtar] ?? "")}
                    onChange={(e) => setOps({ ...ops, [a.anahtar]: e.target.value })}
                  >
                    {(a.secenekler ?? []).map((s) => (
                      <option key={s.deger} value={s.deger}>
                        {t(s.etiket)}
                      </option>
                    ))}
                  </select>
                ) : (
                  <input
                    className={inputCls}
                    type={GIRDI_TIPI[a.tip]}
                    min={a.min}
                    max={a.max}
                    value={String(ops[a.anahtar] ?? "")}
                    onChange={(e) =>
                      setOps({
                        ...ops,
                        [a.anahtar]:
                          a.tip === "sayi"
                            ? e.target.value === ""
                              ? ""
                              : Number(e.target.value)
                            : e.target.value,
                      })
                    }
                  />
                )}
              </Field>
            ))}
            <p className="text-xs text-slate-500">{t("ayarGuvenlikModuAdminNotu")}</p>
            <button className={btnPrimary} disabled={saving} onClick={opKaydet}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
          </motion.section>
        </>
      )}
    </div>
  );
}
