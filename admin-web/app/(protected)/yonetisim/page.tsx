"use client";

import { motion } from "framer-motion";
import Link from "next/link";
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
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("yonKararNo")}</Th>
                  <Th sik>{t("yonKararTarih")}</Th>
                  <Th sik>{t("yonKararKonu")}</Th>
                  <Th sik>{t("yonKararUyeler")}</Th>
                  <Th sik />
                </TabloBasligi>
              <tbody>
                {kararlar.items.map((k) => (
                  <tr key={k.id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik className="font-mono text-xs">{k.karar_no}</Td>
                    <Td sik className="whitespace-nowrap">{formatDateTime(k.tarih)}</Td>
                    <Td sik>{k.konu}</Td>
                    <Td sik>{k.uyeler.map((u) => u.ad).join(", ")}</Td>
                    <Td sik hizala="end">
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
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
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
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("yonDokumanAd")}</Th>
                  <Th sik>{t("yonDokumanYukleyen")}</Th>
                  <Th sik>{t("yonDokumanTarih")}</Th>
                  <Th sik />
                </TabloBasligi>
              <tbody>
                {dokumanlar.items.map((d) => (
                  <tr key={d.id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik>{d.ad}</Td>
                    <Td sik>{d.yukleyen_ad ?? "—"}</Td>
                    <Td sik className="whitespace-nowrap">{formatDateTime(d.created_at)}</Td>
                    <Td sik hizala="end">
                      <button className={btnDanger} onClick={() => dokumanSil(d.id)}>
                        {t("ortakSil")}
                      </button>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
          </div>
        ) : null}
        {/* KAYIT SILINIR, DEPO OBJESI DURUR (P33): tek istekte depoyu da
            silmek, yanlislikla silinen bir yonetim planinin geri
            alinamamasi demekti. */}
        <p className="mt-2 text-xs text-metin-muted">{t("yonDokumanSilmeNotu")}</p>
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
                <span className="text-xs text-metin-muted">{formatDateTime(m.created_at)}</span>
              </li>
            ))}
          </ul>
        ) : null}
        <p className="mb-2 text-xs text-metin-muted">{t("yonKvkkNotu")}</p>
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
            <Tablo>
              <TabloBasligi zeminsiz>
                  <Th sik>{t("yonUyariTarih")}</Th>
                  <Th sik>{t("yonUyariDaire")}</Th>
                  <Th sik>{t("yonUyariSayac")}</Th>
                  <Th sik>{t("yonUyariDurum")}</Th>
                  <Th sik />
                </TabloBasligi>
              <tbody>
                {uyarilar.items.map((u) => (
                  <tr key={u.id} className="border-t border-yuzey-divider dark:border-slate-800">
                    <Td sik className="whitespace-nowrap">{formatDateTime(u.created_at)}</Td>
                    <Td sik>{u.unit_no ?? "—"}</Td>
                    <Td sik sayi>
                      {u.sayac}/{u.esik}
                    </Td>
                    <Td sik>{t(`yonUyariDurum_${u.durum}` as never)}</Td>
                    <Td sik hizala="end">
                      {u.durum === "manuel_bekliyor" ? (
                        <button className={btnGhost} onClick={() => uyariYapildi(u.id)}>
                          {t("yonUyariYapildi")}
                        </button>
                      ) : null}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
          </div>
        ) : null}
      </motion.section>

      {/* (P154 / Asama 8) SITE AKTARIM BURADAN CIKTI. Ice aktarim artik
          TEK CATI uzerinden yapiliyor (`/ice-aktarim`): kolon esleme,
          onizleme, hata raporu ve GERI ALMA orada. Ikinci bir yukleme
          yuzeyi tutmak, ayni akisi iki yerde surdurmek olurdu. */}
      <motion.section {...panelMotion} className={panelCls}>
        <h2 className="mb-1 text-sm font-semibold">{t("yonAktar")}</h2>
        <p className="mb-3 text-xs text-metin-muted">{t("yonAktarTasindi")}</p>
        <Link href="/ice-aktarim" className={btnPrimary}>
          {t("iceAktarimBaslik")}
        </Link>
      </motion.section>
    </div>
  );
}
