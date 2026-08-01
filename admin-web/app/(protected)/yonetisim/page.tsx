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
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * P40 — YONETISIM bolumu (P33 API'si): karar defteri, dokuman arsivi,
 * Excel ile site aktarim.
 *
 * SITE AKTARIM ONCE KURU CALISIR: sunucu `yalniz_dogrula=true` ile hicbir
 * sey yazmaz ve satir bazli hata raporu doner. Panel bu adimi ATLATMAZ —
 * kurulum tek seferlik ve geri almasi zordur; onizlemesiz yapilmasi yanlis
 * bir dosyayi 300 satir boyunca uygulamak olurdu.
 *
 * DOSYA AYRISTIRMA ISTEMCIDE: sunucu XLSX ayristirmaz (saldiri yuzeyi).
 * Panel CSV/yapistirma metnini satirlara cevirir ve JSON gonderir.
 */

interface Uye {
  ad: string;
  gorev?: string | null;
}
interface Karar {
  id: string;
  karar_no: string;
  tarih: string;
  konu: string;
  metin: string;
  baskan_ad: string | null;
  uyeler: Uye[];
}
interface Dokuman {
  id: string;
  ad: string;
  obje_anahtari: string;
  boyut_bayt: number | null;
  yukleyen_ad: string | null;
  created_at: string;
}
interface AktarHata {
  satir_no: number;
  alan: string;
  mesaj: string;
}
interface KvkkMetin {
  id: string;
  surum: number;
  baslik: string;
  govde: string;
  created_at: string;
}
interface Uyari {
  id: string;
  unit_no: string | null;
  esik: number;
  sayac: number;
  kanal: string;
  durum: string;
  created_at: string;
}
interface AktarSonuc {
  blok_olusan: number;
  daire_olusan: number;
  kisi_olusan: number;
  hatalar: AktarHata[];
}

export default function YonetisimPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);

  // ------------------------------ karar defteri ------------------------------
  const { data: kararlar, error: kErr, mutate: kararTazele } = useSWR<{ items: Karar[] }>(
    "/api/panel/karar-defteri?limit=50",
    jsonFetcher,
  );
  const [kNo, setKNo] = useState("");
  const [kKonu, setKKonu] = useState("");
  const [kMetin, setKMetin] = useState("");
  const [kBaskan, setKBaskan] = useState("");
  const [kUyeler, setKUyeler] = useState("");

  async function kararEkle(): Promise<void> {
    setHata(null);
    if (!kNo.trim() || !kKonu.trim() || !kMetin.trim()) {
      setHata(t("yonKararZorunlu"));
      return;
    }
    try {
      await apiSend("/api/panel/karar-defteri", "POST", {
        karar_no: kNo,
        konu: kKonu,
        metin: kMetin,
        baskan_ad: kBaskan || null,
        // Uyeler satir satir girilir; bos satirlar ATILIR (bos ad sunucuda
        // 422 verir ve tum kaydi dusururdu).
        uyeler: kUyeler
          .split("\n")
          .map((x) => x.trim())
          .filter(Boolean)
          .map((ad) => ({ ad })),
      });
      setKNo("");
      setKKonu("");
      setKMetin("");
      setKUyeler("");
      toast.success(t("yonKararEklendi"));
      await kararTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  // -------------------------------- dokumanlar -------------------------------
  const { data: dokumanlar, error: dErr, mutate: dokTazele } = useSWR<{ items: Dokuman[] }>(
    "/api/panel/dokumanlar?limit=50",
    jsonFetcher,
  );

  async function dokumanSil(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/dokumanlar/${id}`, "DELETE");
      toast.success(t("yonDokumanSilindi"));
      await dokTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  // ------------------------------- site aktarim ------------------------------
  const [aktarMetin, setAktarMetin] = useState("");
  const [aktarSonuc, setAktarSonuc] = useState<AktarSonuc | null>(null);
  const [kuruCalisma, setKuruCalisma] = useState(true);

  /** Yapistirilmis metni satirlara cevirir (`blok;daire;ad;telefon;rol`).
   *  Ayirici olarak `;` ve TAB kabul edilir: Excel'den kopyalama TAB uretir,
   *  elle yazan `;` kullanir — birini desteklemek digerini sessizce bos
   *  satira cevirirdi. */
  function satirlariCoz(): Record<string, unknown>[] {
    return aktarMetin
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean)
      .map((satir, i) => {
        const p = satir.split(/[;\t]/).map((x) => x.trim());
        return {
          // Satir numarasi 1 DEGIL 2'den baslar: kullanicinin dosyasinda
          // 1. satir basliktir ve hata raporundaki numaranin Excel'deki
          // satirla ORTUSMESI gerekir.
          satir_no: i + 2,
          blok: p[0] ?? "",
          daire_no: p[1] ?? "",
          ad: p[2] || null,
          telefon: p[3] || null,
          rol_tipi: p[4] || null,
        };
      });
  }

  async function aktar(): Promise<void> {
    setHata(null);
    const satirlar = satirlariCoz();
    if (satirlar.length === 0) {
      setHata(t("yonAktarBos"));
      return;
    }
    try {
      const sonuc = (await apiSend("/api/panel/site-aktar", "POST", {
        yalniz_dogrula: kuruCalisma,
        satirlar,
      })) as AktarSonuc;
      setAktarSonuc(sonuc);
      if (!kuruCalisma) toast.success(t("yonAktarTamam"));
    } catch (e) {
      setAktarSonuc(null);
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  // ------------------------------ KVKK metni --------------------------------
  const { data: kvkk, error: kvErr, mutate: kvkkTazele } = useSWR<KvkkMetin[]>(
    "/api/panel/kvkk-metinler",
    jsonFetcher,
  );
  const [kvBaslik, setKvBaslik] = useState("");
  const [kvGovde, setKvGovde] = useState("");

  async function kvkkYayinla(): Promise<void> {
    setHata(null);
    if (!kvBaslik.trim() || !kvGovde.trim()) {
      setHata(t("yonKvkkZorunlu"));
      return;
    }
    try {
      // YENI SURUM: duzenleme ucu YOKTUR (P36) — yayinlanmis metnin
      // govdesini degistirmek, dun verilen onayi bugun baska bir metne ait
      // gostermek olurdu. Ayni govde 409 doner.
      await apiSend("/api/panel/kvkk-metin", "POST", {
        baslik: kvBaslik,
        govde: kvGovde,
      });
      setKvBaslik("");
      setKvGovde("");
      toast.success(t("yonKvkkYayinlandi"));
      await kvkkTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  // --------------------------- gurultu uyarilari -----------------------------
  const { data: uyarilar, error: uErr, mutate: uyariTazele } = useSWR<{ items: Uyari[] }>(
    "/api/panel/unit-uyarilari?limit=50",
    jsonFetcher,
  );

  async function uyariYapildi(id: string): Promise<void> {
    try {
      // Sunucu "yapildi" VARSAYAMAZ (P37): anonsun gercekten yapilip
      // yapilmadigini yalniz insan bilir.
      await apiSend(`/api/panel/uyari-yapildi/${id}`, "POST");
      toast.success(t("yonUyariIsaretlendi"));
      await uyariTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("yonBaslik")} subtitle={t("yonAlt")} />
      <ErrorBox message={hata} />

      {/* --------------------------- karar defteri ------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("yonKararDefteri")}</h2>
        <ErrorBox message={kErr ? t("yonKararHata") : null} />
        {kararlar && kararlar.items.length === 0 && !kErr ? (
          <EmptyState title={t("yonKararYok")} description={t("yonKararYokAlt")} />
        ) : null}
        {kararlar && kararlar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("yonKararNo")}</th>
                  <th className="px-3 py-2">{t("yonKararTarih")}</th>
                  <th className="px-3 py-2">{t("yonKararKonu")}</th>
                  <th className="px-3 py-2">{t("yonKararUyeler")}</th>
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody>
                {kararlar.items.map((k) => (
                  <tr key={k.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="px-3 py-2 font-mono text-xs">{k.karar_no}</td>
                    <td className="px-3 py-2 whitespace-nowrap">{formatDateTime(k.tarih)}</td>
                    <td className="px-3 py-2">{k.konu}</td>
                    <td className="px-3 py-2">{k.uyeler.map((u) => u.ad).join(", ")}</td>
                    <td className="px-3 py-2 text-right">
                      {/* PDF METIN sablonuyla uretilir (P33): karar bir
                          YAZIDIR, tabloya sikistirmak metni hucrelere
                          bolerdi. */}
                      <a
                        className={btnGhost}
                        href={`/api/panel/karar-pdf/${k.id}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {t("yonKararPdf")}
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}

        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Field label={t("yonKararNo")}>
            <input className={inputCls} value={kNo} onChange={(e) => setKNo(e.target.value)} />
          </Field>
          <Field label={t("yonKararKonu")}>
            <input className={inputCls} value={kKonu} onChange={(e) => setKKonu(e.target.value)} />
          </Field>
          <Field label={t("yonKararBaskan")}>
            <input
              className={inputCls}
              value={kBaskan}
              onChange={(e) => setKBaskan(e.target.value)}
            />
          </Field>
          <Field label={t("yonKararUyeler")}>
            <textarea
              className={`${inputCls} min-h-16`}
              value={kUyeler}
              onChange={(e) => setKUyeler(e.target.value)}
            />
          </Field>
        </div>
        <Field label={t("yonKararMetin")}>
          <textarea
            className={`${inputCls} min-h-24`}
            value={kMetin}
            onChange={(e) => setKMetin(e.target.value)}
          />
        </Field>
        <button className={`${btnPrimary} mt-3`} onClick={kararEkle}>
          {t("yonKararKaydet")}
        </button>
      </motion.section>

      {/* ----------------------------- dokumanlar -------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("yonDokumanlar")}</h2>
        <ErrorBox message={dErr ? t("yonDokumanHata") : null} />
        {dokumanlar && dokumanlar.items.length === 0 && !dErr ? (
          <EmptyState title={t("yonDokumanYok")} description={t("yonDokumanYokAlt")} />
        ) : null}
        {dokumanlar && dokumanlar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("yonDokumanAd")}</th>
                  <th className="px-3 py-2">{t("yonDokumanYukleyen")}</th>
                  <th className="px-3 py-2">{t("yonDokumanTarih")}</th>
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody>
                {dokumanlar.items.map((d) => (
                  <tr key={d.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="px-3 py-2">{d.ad}</td>
                    <td className="px-3 py-2">{d.yukleyen_ad ?? "—"}</td>
                    <td className="px-3 py-2 whitespace-nowrap">{formatDateTime(d.created_at)}</td>
                    <td className="px-3 py-2 text-right">
                      <button className={btnDanger} onClick={() => dokumanSil(d.id)}>
                        {t("ortakSil")}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
        {/* KAYIT SILINIR, DEPO OBJESI DURUR (P33): tek istekte depoyu da
            silmek, yanlislikla silinen bir yonetim planinin geri
            alinamamasi demekti. */}
        <p className="mt-2 text-xs text-slate-500">{t("yonDokumanSilmeNotu")}</p>
      </motion.section>

      {/* ------------------------- KVKK aydinlatma ------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("yonKvkk")}</h2>
        <ErrorBox message={kvErr ? t("yonKvkkHata") : null} />
        {kvkk && kvkk.length === 0 && !kvErr ? (
          <EmptyState title={t("yonKvkkYok")} description={t("yonKvkkYokAlt")} />
        ) : null}
        {kvkk && kvkk.length > 0 ? (
          <ul className="mb-3 space-y-1 text-sm">
            {kvkk.map((m) => (
              <li key={m.id} className="flex justify-between gap-3">
                <span>
                  v{m.surum} · {m.baslik}
                </span>
                <span className="text-xs text-slate-500">{formatDateTime(m.created_at)}</span>
              </li>
            ))}
          </ul>
        ) : null}
        <p className="mb-2 text-xs text-slate-500">{t("yonKvkkNotu")}</p>
        <Field label={t("yonKvkkBaslik")}>
          <input className={inputCls} value={kvBaslik} onChange={(e) => setKvBaslik(e.target.value)} />
        </Field>
        <Field label={t("yonKvkkGovde")}>
          <textarea
            className={`${inputCls} min-h-32`}
            value={kvGovde}
            onChange={(e) => setKvGovde(e.target.value)}
          />
        </Field>
        <button className={`${btnPrimary} mt-3`} onClick={kvkkYayinla}>
          {t("yonKvkkYayinla")}
        </button>
      </motion.section>

      {/* -------------------------- gurultu uyarilari ---------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("yonUyarilar")}</h2>
        <ErrorBox message={uErr ? t("yonUyariHata") : null} />
        {uyarilar && uyarilar.items.length === 0 && !uErr ? (
          <EmptyState title={t("yonUyariYok")} description={t("yonUyariYokAlt")} />
        ) : null}
        {uyarilar && uyarilar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("yonUyariTarih")}</th>
                  <th className="px-3 py-2">{t("yonUyariDaire")}</th>
                  <th className="px-3 py-2">{t("yonUyariSayac")}</th>
                  <th className="px-3 py-2">{t("yonUyariDurum")}</th>
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody>
                {uyarilar.items.map((u) => (
                  <tr key={u.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="px-3 py-2 whitespace-nowrap">{formatDateTime(u.created_at)}</td>
                    <td className="px-3 py-2">{u.unit_no ?? "—"}</td>
                    <td className="px-3 py-2 tabular-nums">
                      {u.sayac}/{u.esik}
                    </td>
                    <td className="px-3 py-2">{t(`yonUyariDurum_${u.durum}` as never)}</td>
                    <td className="px-3 py-2 text-right">
                      {u.durum === "manuel_bekliyor" ? (
                        <button className={btnGhost} onClick={() => uyariYapildi(u.id)}>
                          {t("yonUyariYapildi")}
                        </button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </motion.section>

      {/* ---------------------------- site aktarim ------------------------- */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-3 text-sm font-semibold">{t("yonAktar")}</h2>
        <p className="mb-2 text-xs text-slate-500">{t("yonAktarIpucu")}</p>
        <textarea
          className={`${inputCls} min-h-32 font-mono text-xs`}
          value={aktarMetin}
          onChange={(e) => setAktarMetin(e.target.value)}
        />
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              className="h-4 w-4"
              checked={kuruCalisma}
              onChange={(e) => setKuruCalisma(e.target.checked)}
            />
            {t("yonKuruCalisma")}
          </label>
          <button className={btnPrimary} onClick={aktar}>
            {kuruCalisma ? t("yonAktarDogrula") : t("yonAktarUygula")}
          </button>
        </div>
        {aktarSonuc ? (
          <div className="mt-3 space-y-2 text-sm">
            <div className="text-slate-600 dark:text-slate-400">
              {t("yonAktarBlok")}: <b className="tabular-nums">{aktarSonuc.blok_olusan}</b> ·{" "}
              {t("yonAktarDaire")}: <b className="tabular-nums">{aktarSonuc.daire_olusan}</b> ·{" "}
              {t("yonAktarKisi")}: <b className="tabular-nums">{aktarSonuc.kisi_olusan}</b>
            </div>
            {aktarSonuc.hatalar.length > 0 ? (
              // SATIR BAZLI HATA (P33): 4 hatali satir yuzunden 296 dogru
              // satiri reddetmek, kullaniciyi dosyayi elle ayiklamaya
              // zorlardi — bu yuzden hatalar SATIR NUMARASIYLA listelenir.
              <ul className="rounded bg-rose-50 p-3 text-xs text-rose-900 dark:bg-rose-950 dark:text-rose-200">
                {aktarSonuc.hatalar.map((h, i) => (
                  <li key={i}>
                    #{h.satir_no} · {h.alan} · {h.mesaj}
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : null}
      </motion.section>
    </div>
  );
}
