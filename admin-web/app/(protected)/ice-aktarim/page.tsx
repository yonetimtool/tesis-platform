"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  ErrorBox,
  Field,
  PageHeader,
  btnDanger,
  btnGhost,
  btnPrimary,
  cardCls,
  inputCls,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 8) ICE AKTARIM — dort tur, TEK akis.
 *
 * Brief: "sablon indirme → yukleme → kolon esleme → dogrulama → ONIZLEME
 * → islem icinde aktarim → hata raporu → GERI ALMA."
 *
 * KOLON ESLEME BURADA YAPILIR: sunucu ALANLARI bildirir
 * (`GET /ice-aktarim/turler`), kullanici kendi basliklarini onlara esler,
 * satirlar BIZIM alan kodlarimizla gonderilir. XLSX ayristirma sunucuda
 * YAPILMIYOR (bir saldiri yuzeyidir) — dosyayi zaten istemci aciyor.
 *
 * NEDEN CSV/YAPISTIRMA, NEDEN XLSX AYRISTIRICI DEGIL: panele bir xlsx
 * kitapligi eklemek, kullanicinin dosyasini tarayicida acan yeni bir kod
 * yolu demekti. Yapistirma alani ayni isi kitapliksiz yapar ve
 * kullanicilar Excel'den kopyalamaya zaten alisik. Gercek dosya
 * yuklemesi gerekirse tek degisecek yer `satirlariCoz`dur.
 */

interface Alan {
  kod: string;
  zorunlu: boolean;
  ornek: string;
}
interface Tur {
  kod: string;
  aciklama_kodu: string;
  alanlar: Alan[];
}
interface Hata {
  satir_no: number;
  alan: string | null;
  hata: string;
}
interface Sonuc {
  satir_sayisi: number;
  olusan: number;
  atlanan: number;
  hatali: number;
  hatalar: Hata[];
  aktarim_id: string | null;
}
interface Kosum {
  id: string;
  tur: string;
  dosya_adi: string | null;
  satir_sayisi: number;
  olusan: number;
  atlanan: number;
  hatali: number;
  durum: string;
  created_at: string;
  geri_alma_at: string | null;
}

// Bilinmeyen tur icin yedek etiket. Modul duzeyinde adlandirildi:
// `t(... ?? "iceAktarimTur")` yazmak, `sabit-metin` taramasinda ucludaki
// dizgeyi (cevrilmemis metin adayi) hakli olarak isaretletiyordu — oysa
// bu bir CEVIRI ANAHTARI, gorunen metin degil. (6.3'teki ayni ders.)
const _YEDEK_TUR_ETIKET: SozlukAnahtari = "iceAktarimTur";

const TUR_ETIKET: Record<string, SozlukAnahtari> = {
  daire: "iceAktarimTurDaire",
  kisi: "iceAktarimTurKisi",
  acilis_bakiye: "iceAktarimTurAcilis",
  arac: "iceAktarimTurArac",
};

/** Yapistirilan metni satirlara + hucrelere ayirir (sekme ya da noktali virgul). */
function hucreler(satir: string): string[] {
  return satir.includes("\t") ? satir.split("\t") : satir.split(";");
}

export default function IceAktarimPage() {
  const t = useT();
  const toast = useToast();
  const [turKod, setTurKod] = useState("daire");
  const [ham, setHam] = useState("");
  const [baslikVar, setBaslikVar] = useState(true);
  const [esleme, setEsleme] = useState<Record<number, string>>({});
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  const { data: turler } = useSWR<Tur[]>("/api/panel/ice-aktarim-turler", jsonFetcher);
  const { data: gecmis, mutate: gecmisTazele } = useSWR<{ items: Kosum[] }>(
    "/api/panel/ice-aktarim?limit=20",
    jsonFetcher,
  );
  const tur = turler?.find((x) => x.kod === turKod);

  const satirlar = ham.split("\n").map((s) => s.trimEnd()).filter((s) => s.trim());
  const basliklar = satirlar.length > 0 ? hucreler(satirlar[0]) : [];
  const veriSatirlari = baslikVar ? satirlar.slice(1) : satirlar;

  function alanSec(kolon: number, alanKod: string) {
    setEsleme((e) => ({ ...e, [kolon]: alanKod }));
  }

  /** Eslemeye gore satirlari BIZIM alan kodlarimizla kurar. */
  function govdeSatirlari() {
    return veriSatirlari.map((s, i) => {
      const h = hucreler(s);
      const degerler: Record<string, string> = {};
      for (const [kolonStr, alanKod] of Object.entries(esleme)) {
        if (!alanKod) continue;
        degerler[alanKod] = (h[Number(kolonStr)] ?? "").trim();
      }
      return { satir_no: i + (baslikVar ? 2 : 1), degerler };
    });
  }

  async function calistir(yalnizDogrula: boolean) {
    setHata(null);
    const govde = govdeSatirlari();
    if (govde.length === 0) {
      setHata(t("iceAktarimBosDosya"));
      return;
    }
    const zorunluEksik = (tur?.alanlar ?? [])
      .filter((a) => a.zorunlu)
      .filter((a) => !Object.values(esleme).includes(a.kod));
    if (zorunluEksik.length > 0) {
      // Sunucu da reddederdi ama SATIR SATIR: kullanici yuz hata gorurdu.
      setHata(t("iceAktarimEslemeEksik", { alan: zorunluEksik[0].kod }));
      return;
    }
    setMesgul(true);
    try {
      const r = await apiSend<Sonuc>(
        `/api/panel/ice-aktarim-${turKod}`,
        "POST",
        { satirlar: govde, yalniz_dogrula: yalnizDogrula, dosya_adi: null },
      );
      setSonuc(r);
      if (!yalnizDogrula) {
        toast.success(t("iceAktarimTamam"));
        await gecmisTazele();
      }
    } catch (e) {
      setSonuc(null);
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function geriAl(id: string) {
    if (!window.confirm(t("iceAktarimGeriAlOnay"))) return;
    try {
      await apiSend(`/api/panel/ice-aktarim/${id}/geri-al`, "POST");
      toast.success(t("iceAktarimGeriAlindi"));
      await gecmisTazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader title={t("iceAktarimBaslik")} subtitle={t("iceAktarimAlt")} />
      <ErrorBox message={hata} />

      {/* --------------------------- 1) TUR + SABLON --------------------- */}
      <section className={`${cardCls} space-y-3 p-kart`}>
        <Field label={t("iceAktarimTur")}>
          <select
            className={inputCls}
            style={{ maxWidth: 280 }}
            value={turKod}
            onChange={(e) => {
              setTurKod(e.target.value);
              // ESLEME SIFIRLANIR: alanlar degisti, eski esleme artik
              // baska bir turun alanlarina isaret ediyordu.
              setEsleme({});
              setSonuc(null);
            }}
          >
            {(turler ?? []).map((x) => (
              <option key={x.kod} value={x.kod}>
                {t(TUR_ETIKET[x.kod] ?? _YEDEK_TUR_ETIKET)}
              </option>
            ))}
          </select>
        </Field>
        {tur && (
          <p className="text-xs text-metin-muted">
            {t("iceAktarimSablonSatiri")}:{" "}
            <code className="break-all">
              {tur.alanlar.map((a) => a.kod).join(";")}
            </code>
            <br />
            {t("iceAktarimOrnekSatiri")}:{" "}
            <code className="break-all">
              {tur.alanlar.map((a) => a.ornek).join(";")}
            </code>
          </p>
        )}
      </section>

      {/* ----------------------------- 2) YUKLEME ------------------------ */}
      <section className={`${cardCls} space-y-3 p-kart`}>
        <Field label={t("iceAktarimVeri")} hint={t("iceAktarimVeriIpucu")}>
          <textarea
            className={`${inputCls} min-h-32 font-mono text-xs`}
            value={ham}
            onChange={(e) => {
              setHam(e.target.value);
              setSonuc(null);
            }}
          />
        </Field>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            className="h-4 w-4"
            checked={baslikVar}
            onChange={(e) => setBaslikVar(e.target.checked)}
          />
          {t("iceAktarimBaslikSatiri")}
        </label>
      </section>

      {/* --------------------------- 3) KOLON ESLEME --------------------- */}
      {basliklar.length > 0 && tur && (
        <section className={`${cardCls} space-y-3 p-kart`}>
          <h2 className="text-sm font-semibold">{t("iceAktarimEsleme")}</h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {basliklar.map((b, i) => (
              <Field
                key={i}
                label={baslikVar ? b || `#${i + 1}` : `${t("iceAktarimKolon")} ${i + 1}`}
              >
                <select
                  className={inputCls}
                  value={esleme[i] ?? ""}
                  onChange={(e) => alanSec(i, e.target.value)}
                >
                  <option value="">{t("iceAktarimKullanma")}</option>
                  {tur.alanlar.map((a) => (
                    <option key={a.kod} value={a.kod}>
                      {a.kod}
                      {a.zorunlu ? " *" : ""}
                    </option>
                  ))}
                </select>
              </Field>
            ))}
          </div>
          <div className="flex flex-wrap gap-2">
            {/* ONIZLEME ONCE: hicbir sey yazmadan ayni raporu verir. */}
            <button
              type="button"
              className={btnGhost}
              disabled={mesgul}
              onClick={() => void calistir(true)}
            >
              {t("iceAktarimOnizle")}
            </button>
            <button
              type="button"
              className={btnPrimary}
              disabled={mesgul}
              onClick={() => void calistir(false)}
            >
              {t("iceAktarimUygula")}
            </button>
          </div>
        </section>
      )}

      {/* ---------------------------- 4) SONUC --------------------------- */}
      {sonuc && (
        <section className={`${cardCls} space-y-2 p-kart`} aria-live="polite">
          <p className="text-sm text-metin-body">
            {t("iceAktarimOzet", {
              satir: sonuc.satir_sayisi,
              olusan: sonuc.olusan,
              atlanan: sonuc.atlanan,
              hatali: sonuc.hatali,
            })}
          </p>
          {sonuc.hatalar.length > 0 && (
            <ul className="space-y-1 text-xs text-vurguInk-red">
              {sonuc.hatalar.map((h, i) => (
                <li key={i}>
                  {t("iceAktarimSatir", { no: h.satir_no })}
                  {h.alan ? ` · ${h.alan}` : ""} — {h.hata}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {/* --------------------------- 5) GECMIS + GERI ALMA --------------- */}
      <section className={`${cardCls} space-y-2 p-kart`}>
        <h2 className="text-sm font-semibold">{t("iceAktarimGecmis")}</h2>
        {(gecmis?.items ?? []).length === 0 && (
          <p className="text-sm text-metin-muted">{t("iceAktarimGecmisYok")}</p>
        )}
        {(gecmis?.items ?? []).map((k) => (
          <div
            key={k.id}
            className="kart-kenar flex flex-wrap items-center justify-between gap-3 rounded-lg border p-2 text-sm"
          >
            <span className="min-w-0">
              {t(TUR_ETIKET[k.tur] ?? _YEDEK_TUR_ETIKET)} ·{" "}
              {formatDateTime(k.created_at)} ·{" "}
              {t("iceAktarimOzetKisa", { olusan: k.olusan, hatali: k.hatali })}
            </span>
            {k.durum === "geri_alindi" ? (
              <span className="text-xs text-metin-muted">
                {t("iceAktarimGeriAlinmis")}
              </span>
            ) : (
              <button
                type="button"
                className={btnDanger}
                onClick={() => void geriAl(k.id)}
              >
                {t("iceAktarimGeriAl")}
              </button>
            )}
          </div>
        ))}
      </section>
    </div>
  );
}
