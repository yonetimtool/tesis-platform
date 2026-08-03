"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnDanger,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";

/**
 * P40 — PORTAL yonetimi (P38 API'si): icerik + yayin anahtari + anketler +
 * gelen iletisim mesajlari.
 *
 * YAYIN ANAHTARI EN USTTE ve VARSAYILAN KAPALIDIR: bir tesisin adi, adresi
 * ve fotograflari yonetim ACIKCA yayinlamadan internete cikmamalidir.
 * Anahtarin sayfanin altinda kalmasi, "doldurdum ama yayinlamadim" ile
 * "yayinladim" arasindaki farki gorunmez kilardi.
 *
 * ANKET SONUCU acikken GIZLIDIR (surusel etki) — ama YONETIM her zaman
 * gorur; bu sayfa sunucunun dondurdugu sayilari cizer, kendisi saymaz.
 */

interface Portal {
  yayinda: boolean;
  hero_baslik: string | null;
  hero_alt: string | null;
  hakkimizda: string | null;
  iletisim_adres: string | null;
  iletisim_telefon: string | null;
  iletisim_email: string | null;
}
interface Secenek {
  id: string;
  metin: string;
  oy: number | null;
}
interface Anket {
  id: string;
  baslik: string;
  aciklama: string | null;
  acik: boolean;
  aktif: boolean;
  toplam_oy: number | null;
  secenekler: Secenek[];
}
interface Mesaj {
  id: string;
  ad: string;
  telefon: string | null;
  email: string | null;
  mesaj: string;
  created_at: string;
}

export default function PortalPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);

  const { data: portal, error: pErr, mutate: portalTazele } = useSWR<Portal>(
    "/api/panel/portal",
    jsonFetcher,
  );
  const { data: anketler, error: aErr, mutate: anketTazele } = useSWR<{ items: Anket[] }>(
    "/api/panel/anketler?limit=50",
    jsonFetcher,
  );
  const { data: mesajlar, error: mErr } = useSWR<{ items: Mesaj[] }>(
    "/api/panel/portal-iletisim?limit=50",
    jsonFetcher,
  );

  const [form, setForm] = useState<Portal | null>(null);
  useEffect(() => {
    if (portal && !form) setForm(portal);
  }, [portal, form]);

  async function kaydet(alanlar: Partial<Portal>): Promise<void> {
    setHata(null);
    try {
      await apiSend("/api/panel/portal", "PATCH", alanlar);
      toast.success(t("portalKaydedildi"));
      await portalTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  // --- yeni anket ---
  const [aBaslik, setABaslik] = useState("");
  const [aSecenek, setASecenek] = useState("");

  async function anketEkle(): Promise<void> {
    setHata(null);
    const secenekler = aSecenek
      .split("\n")
      .map((x) => x.trim())
      .filter(Boolean)
      .map((metin, i) => ({ metin, sira: i }));
    if (!aBaslik.trim() || secenekler.length < 2) {
      // EN AZ IKI secenek (P38): tek secenekli anket oy toplamaz, ONAY
      // toplar — bunu sunucuya sorup 422 almak yerine burada soyluyoruz.
      setHata(t("portalAnketEnAzIki"));
      return;
    }
    try {
      await apiSend("/api/panel/anketler", "POST", { baslik: aBaslik, secenekler });
      setABaslik("");
      setASecenek("");
      toast.success(t("portalAnketEklendi"));
      await anketTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  async function anketKapat(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/anketler/${id}`, "PATCH", { aktif: false });
      toast.success(t("portalAnketKapatildi"));
      await anketTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("portalBaslik")} subtitle={t("portalAlt")} />
      <ErrorBox message={hata ?? (pErr ? t("portalHata") : null)} />

      {/* ------------------------------ yayin ------------------------------ */}
      {form ? (
        <motion.section {...panelMotion} className={panelCls}>
          <label className="flex items-center gap-3 text-sm font-medium">
            <input
              type="checkbox"
              className="h-4 w-4"
              checked={form.yayinda}
              onChange={(e) => {
                setForm({ ...form, yayinda: e.target.checked });
                kaydet({ yayinda: e.target.checked });
              }}
            />
            {t("portalYayinda")}
          </label>
          <p className="mt-1 text-xs text-slate-500">{t("portalYayinNotu")}</p>
        </motion.section>
      ) : null}

      {/* ------------------------------ icerik ----------------------------- */}
      {form ? (
        <motion.section {...panelMotion} className={panelCls}>
          <h2 className="mb-3 text-sm font-semibold">{t("portalIcerik")}</h2>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t("portalHeroBaslik")}>
              <input
                className={inputCls}
                value={form.hero_baslik ?? ""}
                onChange={(e) => setForm({ ...form, hero_baslik: e.target.value })}
              />
            </Field>
            <Field label={t("portalHeroAlt")}>
              <input
                className={inputCls}
                value={form.hero_alt ?? ""}
                onChange={(e) => setForm({ ...form, hero_alt: e.target.value })}
              />
            </Field>
            <Field label={t("portalAdres")}>
              <input
                className={inputCls}
                value={form.iletisim_adres ?? ""}
                onChange={(e) => setForm({ ...form, iletisim_adres: e.target.value })}
              />
            </Field>
            <Field label={t("portalTelefon")}>
              <input
                className={inputCls}
                value={telefonGiris(form.iletisim_telefon ?? "")}
                // (P123) TEK bicimlendirici: gruplar, rakam disini yutar,
                // uzunlugu SERT sinirlar, yapistirmayi cozer.
                onChange={(e) => setForm({ ...form, iletisim_telefon: telefonGiris(e.target.value) })}
              />
            </Field>
            <Field label={t("portalEposta")}>
              <input
                className={inputCls}
                value={form.iletisim_email ?? ""}
                onChange={(e) => setForm({ ...form, iletisim_email: e.target.value })}
              />
            </Field>
          </div>
          <Field label={t("portalHakkimizda")} hint={t("portalHakkimizdaIpucu")}>
            <textarea
              className={`${inputCls} min-h-32`}
              value={form.hakkimizda ?? ""}
              onChange={(e) => setForm({ ...form, hakkimizda: e.target.value })}
            />
          </Field>
          <button
            className={`${btnPrimary} mt-3`}
            onClick={() =>
              kaydet({
                hero_baslik: form.hero_baslik,
                hero_alt: form.hero_alt,
                hakkimizda: form.hakkimizda,
                iletisim_adres: form.iletisim_adres,
                // Sunucuya NORMALLESTIRILMIS gider (ayni numara tek yazimla saklansin).
                iletisim_telefon: telefonNormalle(form.iletisim_telefon ?? "") || null,
                iletisim_email: form.iletisim_email,
              })
            }
          >
            {t("ortakKaydet")}
          </button>
        </motion.section>
      ) : null}

      {/* ------------------------------ anket ------------------------------ */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("portalAnketler")}</h2>
        <ErrorBox message={aErr ? t("portalAnketHata") : null} />
        {anketler && anketler.items.length === 0 && !aErr ? (
          <EmptyState title={t("portalAnketYok")} description={t("portalAnketYokAlt")} />
        ) : null}
        <div className="space-y-3">
          {(anketler?.items ?? []).map((a) => (
            <div
              key={a.id}
              className="rounded-lg border border-slate-200 p-3 text-sm dark:border-slate-700"
            >
              <div className="flex items-center justify-between gap-3">
                <span className="font-medium">{a.baslik}</span>
                <span className="text-xs text-slate-500">
                  {a.acik ? t("portalAnketAcik") : t("portalAnketKapali")}
                  {a.toplam_oy != null ? ` · ${a.toplam_oy}` : ""}
                </span>
              </div>
              <ul className="mt-2 space-y-1 text-xs">
                {a.secenekler.map((s) => (
                  <li key={s.id} className="flex justify-between">
                    <span>{s.metin}</span>
                    {/* Yonetim sonucu HER ZAMAN gorur (P38) — sayi sunucudan
                        gelmiyorsa hic cizilmez, sifir UYDURULMAZ. */}
                    {s.oy != null ? <span className="tabular-nums">{s.oy}</span> : null}
                  </li>
                ))}
              </ul>
              {a.aktif ? (
                <button className={`${btnDanger} mt-2`} onClick={() => anketKapat(a.id)}>
                  {t("portalAnketKapat")}
                </button>
              ) : null}
            </div>
          ))}
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <Field label={t("portalAnketBaslik")}>
            <input
              className={inputCls}
              value={aBaslik}
              onChange={(e) => setABaslik(e.target.value)}
            />
          </Field>
          <Field label={t("portalAnketSecenekler")} hint={t("portalAnketSecenekIpucu")}>
            <textarea
              className={`${inputCls} min-h-20`}
              value={aSecenek}
              onChange={(e) => setASecenek(e.target.value)}
            />
          </Field>
        </div>
        <button className={`${btnPrimary} mt-3`} onClick={anketEkle}>
          {t("portalAnketEkle")}
        </button>
      </motion.section>

      {/* ---------------------------- iletisim ----------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("portalMesajlar")}</h2>
        <ErrorBox message={mErr ? t("portalMesajHata") : null} />
        {mesajlar && mesajlar.items.length === 0 && !mErr ? (
          <EmptyState title={t("portalMesajYok")} description={t("portalMesajYokAlt")} />
        ) : null}
        {mesajlar && mesajlar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("portalMesajTarih")}</th>
                  <th className="px-3 py-2">{t("portalMesajAd")}</th>
                  <th className="px-3 py-2">{t("portalMesajIletisim")}</th>
                  <th className="px-3 py-2">{t("portalMesajMetin")}</th>
                </tr>
              </thead>
              <tbody>
                {mesajlar.items.map((m) => (
                  <tr key={m.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="px-3 py-2 whitespace-nowrap">{formatDateTime(m.created_at)}</td>
                    <td className="px-3 py-2">{m.ad}</td>
                    <td className="px-3 py-2">{m.telefon ?? m.email}</td>
                    <td className="px-3 py-2">{m.mesaj}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </motion.section>
    </div>
  );
}
