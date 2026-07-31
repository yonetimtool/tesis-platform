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
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * P27 "Tanimlar" — dokuz kayit defteri TEK sayfada, sekmeli.
 *
 * NEDEN TEK SAYFA: bunlarin hepsi site KURULUM adimidir ve kullanici art
 * arda doldurur; menuye dokuz ayri giris koymak, kabugu tanimlarla
 * doldurup gunluk kullanilan sayfalari (aidat, talepler) asagi iterdi.
 *
 * NEDEN VERI-SURUCULU: dokuz defter icin dokuz form bileseni yazmak ayni
 * kodu dokuz kez kopyalamak olurdu. Her defter bir ALAN TANIMI listesiyle
 * anlatilir; tablo ve form bundan uretilir.
 */

type AlanTip = "metin" | "sayi" | "kurus" | "tarih" | "bool" | "secim";

interface Alan {
  ad: string;
  /** METIN DEGIL ANAHTAR (tur 17/22 kilitleri): etiket cizim aninda aktif
   *  dilde cozulur; sabit Turkce dil degisiminde oldugu gibi kalirdi. */
  etiket: SozlukAnahtari;
  tip: AlanTip;
  zorunlu?: boolean;
  secenekler?: string[];
  /** Listede sutun olarak gosterilsin mi (hepsi gosterilirse tablo tasar). */
  sutun?: boolean;
}

interface Defter {
  kaynak: string;
  baslikAnahtari: SozlukAnahtari;
  alanlar: Alan[];
}

const DEFTERLER: Defter[] = [
  {
    kaynak: "kasalar",
    baslikAnahtari: "tanimKasalar",
    alanlar: [
      { ad: "kod", etiket: "tanimAlanKod", tip: "metin", zorunlu: true, sutun: true },
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "acilis_tarihi", etiket: "tanimAlanAcilisTarihi", tip: "tarih" },
      { ad: "acilis_bakiye_kurus", etiket: "tanimAlanAcilisBakiye", tip: "kurus", sutun: true },
      { ad: "banka_mi", etiket: "tanimAlanBankaMi", tip: "bool", sutun: true },
      { ad: "iban", etiket: "tanimAlanIban", tip: "metin" },
      { ad: "banka_adi", etiket: "tanimAlanBankaAdi", tip: "metin" },
      { ad: "sube", etiket: "tanimAlanSube", tip: "metin" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "gelir-gider-gruplari",
    baslikAnahtari: "tanimGelirGiderGruplari",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
  },
  {
    kaynak: "gelir-gider-tanimlari",
    baslikAnahtari: "tanimGelirGiderTanimlari",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      {
        ad: "tip",
        etiket: "tanimAlanTip",
        tip: "secim",
        zorunlu: true,
        secenekler: ["gelir", "gider", "her_ikisi"],
        sutun: true,
      },
      {
        // GELIR kaleminde dagitim OLMAZ (sunucu 422) — alt metin bunu soyler.
        ad: "dagitim_sekli",
        etiket: "tanimAlanDagitim",
        tip: "secim",
        secenekler: ["bagimsiz_bolumlere_esit", "tipe_gore"],
        sutun: true,
      },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "firmalar",
    baslikAnahtari: "tanimFirmalar",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "vergi_no", etiket: "tanimAlanVergiNo", tip: "metin", sutun: true },
      { ad: "vergi_dairesi", etiket: "tanimAlanVergiDairesi", tip: "metin" },
      { ad: "telefon", etiket: "tanimAlanTelefon", tip: "metin", sutun: true },
      { ad: "email", etiket: "tanimAlanEposta", tip: "metin" },
      { ad: "yetkili_ad", etiket: "tanimAlanYetkili", tip: "metin" },
      { ad: "acilis_bakiye_kurus", etiket: "tanimAlanAcilisBakiye", tip: "kurus" },
      {
        ad: "acilis_bakiye_yon",
        etiket: "tanimAlanBakiyeYonu",
        tip: "secim",
        secenekler: ["borc", "alacak"],
      },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "personel-kayitlari",
    baslikAnahtari: "tanimPersonel",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "gorev", etiket: "tanimAlanGorev", tip: "metin", sutun: true },
      { ad: "tc", etiket: "tanimAlanTc", tip: "metin" },
      { ad: "telefon", etiket: "tanimAlanTelefon", tip: "metin", sutun: true },
      { ad: "giris_tarihi", etiket: "tanimAlanGirisTarihi", tip: "tarih" },
      { ad: "cikis_tarihi", etiket: "tanimAlanCikisTarihi", tip: "tarih" },
      { ad: "maas_kurus", etiket: "tanimAlanMaas", tip: "kurus" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "arac-kayitlari",
    baslikAnahtari: "tanimAraclar",
    alanlar: [
      { ad: "plaka", etiket: "tanimAlanPlaka", tip: "metin", zorunlu: true, sutun: true },
      { ad: "marka", etiket: "tanimAlanMarka", tip: "metin", sutun: true },
      { ad: "model", etiket: "tanimAlanModel", tip: "metin", sutun: true },
      { ad: "renk", etiket: "tanimAlanRenk", tip: "metin" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "sayaclar-ana",
    baslikAnahtari: "tanimSayaclar",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      {
        ad: "tip",
        etiket: "tanimAlanTip",
        tip: "secim",
        secenekler: ["su", "elektrik", "dogalgaz", "isi", "diger"],
        sutun: true,
      },
      { ad: "tesisat_no", etiket: "tanimAlanTesisatNo", tip: "metin" },
      { ad: "ortak_alan_yuzde", etiket: "tanimAlanOrtakAlanYuzde", tip: "sayi", sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
];

type Kayit = Record<string, unknown>;

/** Kurus <-> TL: kullanici lira girer, sunucu kurus bekler. */
function kurusaCevir(metin: string): number | null {
  const t = metin.trim().replace(",", ".");
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
}
function liraya(kurus: unknown): string {
  if (typeof kurus !== "number") return "";
  return (kurus / 100).toFixed(2);
}

/** HTML `type`/`inputMode` — UCLU DEGIL TABLO: sabit-metin tarayicisi
 *  (tur 47) ucludaki her dizgiyi cevrilmemis metin sanar ve `date`/`text`
 *  gibi teknik degerler icin de uyarir. Tabloya cevirmek hem taramayi
 *  memnun eder hem de tip eklendiginde derleyicinin burayi gostermesini
 *  saglar (`Record<AlanTip, ...>` eksik anahtari yakalar). */
const GIRIS_TIPI: Record<AlanTip, string> = {
  metin: "text",
  sayi: "text",
  kurus: "text",
  tarih: "date",
  bool: "checkbox",
  secim: "text",
};
const GIRIS_MODU: Partial<Record<AlanTip, "decimal">> = {
  sayi: "decimal",
  kurus: "decimal",
};
function girisTipi(tip: AlanTip): string {
  return GIRIS_TIPI[tip];
}
// Donus tipi CIKARIMLA gelir: acik anotasyon bir dizgi sabiti icerirdi ve
// sabit-metin taramasi onu da cevrilmemis metin sayardi.
function girisModu(tip: AlanTip) {
  return GIRIS_MODU[tip];
}

function formDegeri(alan: Alan, kayit: Kayit | null): string | boolean {
  const ham = kayit?.[alan.ad];
  if (alan.tip === "bool") return ham === undefined ? true : Boolean(ham);
  if (alan.tip === "kurus") return liraya(ham);
  return ham === null || ham === undefined ? "" : String(ham);
}

export default function TanimlarPage() {
  const t = useT();
  const [sekme, setSekme] = useState(0);
  const defter = DEFTERLER[sekme];
  return (
    <div className="space-y-4">
      <PageHeader title={t("kabukTanimlar")} />
      <div className="flex flex-wrap gap-2">
        {DEFTERLER.map((d, i) => (
          <button
            key={d.kaynak}
            type="button"
            onClick={() => setSekme(i)}
            className={i === sekme ? btnPrimary : btnGhost}
          >
            {t(d.baslikAnahtari)}
          </button>
        ))}
        <button
          type="button"
          onClick={() => setSekme(-1)}
          className={sekme === -1 ? btnPrimary : btnGhost}
        >
          {t("tanimAyarlar")}
        </button>
      </div>
      {sekme === -1 ? <Ayarlar /> : <DefterGorunumu key={defter.kaynak} defter={defter} />}
    </div>
  );
}

function DefterGorunumu({ defter }: { defter: Defter }) {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Kayit[] }>(
    `/api/tanimlar/${defter.kaynak}?limit=200`,
    jsonFetcher,
  );
  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<Kayit | null>(null);
  const [form, setForm] = useState<Record<string, string | boolean>>({});
  const [formHata, setFormHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  function ac(kayit: Kayit | null) {
    setDuzenlenen(kayit);
    const yeni: Record<string, string | boolean> = {};
    for (const a of defter.alanlar) yeni[a.ad] = formDegeri(a, kayit);
    setForm(yeni);
    setFormHata(null);
    setAcik(true);
  }

  async function kaydet() {
    const govde: Record<string, unknown> = {};
    for (const a of defter.alanlar) {
      const v = form[a.ad];
      if (a.tip === "bool") {
        govde[a.ad] = Boolean(v);
        continue;
      }
      const metin = String(v ?? "").trim();
      if (metin === "") {
        if (a.zorunlu) {
          setFormHata(t("tanimZorunluAlan", { alan: t(a.etiket) }));
          return;
        }
        // BOS = "deger yok": null gonderilir, "" degil — sunucu bicim
        // dogrulamasi bos metni gecersiz sayardi.
        govde[a.ad] = null;
        continue;
      }
      if (a.tip === "kurus") govde[a.ad] = kurusaCevir(metin);
      else if (a.tip === "sayi") govde[a.ad] = Number(metin);
      else govde[a.ad] = metin;
    }
    setKaydediyor(true);
    setFormHata(null);
    const yol = duzenlenen
      ? `/api/tanimlar/${defter.kaynak}/${String(duzenlenen.id)}`
      : `/api/tanimlar/${defter.kaynak}`;
    // `apiSend` HATA FIRLATIR (donen nesnede bayrak yok) — sunucunun
    // katalog metni `ApiHatasi.message`tedir ve forma yazilir.
    try {
      await apiSend(yol, duzenlenen ? "PATCH" : "POST", govde);
    } catch (e) {
      setKaydediyor(false);
      setFormHata(e instanceof Error ? e.message : String(e));
      return;
    }
    setKaydediyor(false);
    setAcik(false);
    toast.success(t("ortakKaydet"));
    void mutate();
  }

  async function sil(kayit: Kayit) {
    if (!window.confirm(t("tanimSilOnay"))) return;
    try {
      await apiSend(`/api/tanimlar/${defter.kaynak}/${String(kayit.id)}`, "DELETE");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e));
      return;
    }
    void mutate();
  }

  const sutunlar = defter.alanlar.filter((a) => a.sutun);
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-3">
      <div className="flex justify-end">
        <button type="button" className={btnPrimary} onClick={() => ac(null)}>
          {t("tanimYeniKayit")}
        </button>
      </div>
      {error ? <ErrorBox message={String(error)} /> : null}
      {isLoading ? <p>{t("ortakYukleniyor")}</p> : null}
      {!isLoading && kayitlar.length === 0 ? (
        <EmptyState title={t("tanimKayitYok")} />
      ) : null}
      {kayitlar.length > 0 ? (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr>
                {sutunlar.map((a) => (
                  <th key={a.ad} className="p-2 text-start">
                    {t(a.etiket)}
                  </th>
                ))}
                <th className="p-2" />
              </tr>
            </thead>
            <tbody>
              {kayitlar.map((k) => (
                <tr key={String(k.id)} className="border-t">
                  {sutunlar.map((a) => (
                    <td key={a.ad} className="p-2">
                      {a.tip === "bool"
                        ? k[a.ad]
                          ? "✓"
                          : "—"
                        : a.tip === "kurus"
                          ? liraya(k[a.ad])
                          : String(k[a.ad] ?? "—")}
                    </td>
                  ))}
                  <td className="p-2 text-end whitespace-nowrap">
                    <button type="button" className={btnGhost} onClick={() => ac(k)}>
                      {t("ortakDuzenle")}
                    </button>{" "}
                    <button type="button" className={btnDanger} onClick={() => void sil(k)}>
                      {t("ortakSil")}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      {acik ? (
        <motion.div {...panelMotion} className={panelCls}>
          <ErrorBox message={formHata} />
          <div className="grid gap-3 sm:grid-cols-2">
            {defter.alanlar.map((a) => (
              <Field key={a.ad} label={t(a.etiket)}>
                {a.tip === "bool" ? (
                  <input
                    type="checkbox"
                    checked={Boolean(form[a.ad])}
                    onChange={(e) => setForm({ ...form, [a.ad]: e.target.checked })}
                  />
                ) : a.tip === "secim" ? (
                  <select
                    className={inputCls}
                    value={String(form[a.ad] ?? "")}
                    onChange={(e) => setForm({ ...form, [a.ad]: e.target.value })}
                  >
                    <option value="">—</option>
                    {(a.secenekler ?? []).map((s) => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                ) : (
                  <input
                    className={inputCls}
                    type={girisTipi(a.tip)}
                    inputMode={girisModu(a.tip)}
                    value={String(form[a.ad] ?? "")}
                    onChange={(e) => setForm({ ...form, [a.ad]: e.target.value })}
                  />
                )}
              </Field>
            ))}
          </div>
          <div className="mt-3 flex gap-2">
            <button
              type="button"
              className={btnPrimary}
              disabled={kaydediyor}
              onClick={() => void kaydet()}
            >
              {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setAcik(false)}>
              {t("ortakVazgec")}
            </button>
          </div>
        </motion.div>
      ) : null}
    </div>
  );
}

function Ayarlar() {
  const t = useT();
  const toast = useToast();
  const { data, mutate } = useSWR<{
    evrak_seri: string;
    evrak_sira: number;
    para_birimi: string;
  }>("/api/muhasebe-ayarlari", jsonFetcher);
  const [form, setForm] = useState<Record<string, string>>({});
  const [hata, setHata] = useState<string | null>(null);

  const seri = form.evrak_seri ?? data?.evrak_seri ?? "";
  const sira = form.evrak_sira ?? String(data?.evrak_sira ?? "");
  const para = form.para_birimi ?? data?.para_birimi ?? "";

  async function kaydet() {
    try {
      await apiSend("/api/muhasebe-ayarlari", "PATCH", {
        evrak_seri: seri,
        evrak_sira: Number(sira),
        para_birimi: para,
      });
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
      return;
    }
    setHata(null);
    toast.success(t("ortakKaydet"));
    void mutate();
  }

  return (
    <motion.div {...panelMotion} className={panelCls}>
      <ErrorBox message={hata} />
      <div className="grid gap-3 sm:grid-cols-3">
        <Field label={t("tanimAlanEvrakSeri")}>
          <input
            className={inputCls}
            value={seri}
            onChange={(e) => setForm({ ...form, evrak_seri: e.target.value.toUpperCase() })}
          />
        </Field>
        <Field label={t("tanimAlanEvrakSira")}>
          <input
            className={inputCls}
            inputMode="numeric"
            value={sira}
            onChange={(e) => setForm({ ...form, evrak_sira: e.target.value })}
          />
        </Field>
        <Field label={t("tanimAlanParaBirimi")}>
          <input
            className={inputCls}
            value={para}
            onChange={(e) => setForm({ ...form, para_birimi: e.target.value.toUpperCase() })}
          />
        </Field>
      </div>
      {/* Para biriminin YALNIZ gosterim oldugu ekranda YAZAR: aksi halde
          kullanici kur cevirisi bekler ve sessizce yanlis toplam okur. */}
      <p className="mt-2 text-sm opacity-70">{t("tanimParaBirimiNotu")}</p>
      <div className="mt-3">
        <button type="button" className={btnPrimary} onClick={() => void kaydet()}>
          {t("ortakKaydet")}
        </button>
      </div>
    </motion.div>
  );
}
