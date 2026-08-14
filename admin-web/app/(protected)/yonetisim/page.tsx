"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import {
  CokSatir,
  Kart,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
} from "@/components/ui";
import { Tablo, TabloBasligi, Td, Th } from "@/components/tablo";
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
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("yonBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("yonAlt")}
        </p>
      </div>
      <HataDurumu mesaj={hata} />

      {/* --------------------------- karar defteri ------------------------- */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("yonKararDefteri")}</h2>
        <HataDurumu mesaj={kErr ? t("yonKararHata") : null} />
        {kararlar && kararlar.items.length === 0 && !kErr ? (
          <BosDurum baslik={t("yonKararYok")} aciklama={t("yonKararYokAlt")} />
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
                        className="odak-ic underline"
                        style={{
                          fontSize: "var(--yz-fs-sm)",
                          color: "var(--yz-accent-ink)",
                        }}
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
          <AlanSarmal etiket={t("yonKararNo")}>
  {(b) => (
    <Alan {...b} value={kNo} onChange={(e) => setKNo(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("yonKararKonu")}>
  {(b) => (
    <Alan {...b} value={kKonu} onChange={(e) => setKKonu(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("yonKararBaskan")}>
  {(b) => (
    <Alan {...b} value={kBaskan}
              onChange={(e) => setKBaskan(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("yonKararUyeler")}>
            {(b) => (
              <CokSatir {...b} rows={4} value={kUyeler}
              onChange={(e) => setKUyeler(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <AlanSarmal etiket={t("yonKararMetin")}>
            {(b) => (
              <CokSatir {...b} rows={4} value={kMetin}
            onChange={(e) => setKMetin(e.target.value)} />
            )}
          </AlanSarmal>
        <Dugme tur="birincil" onClick={kararEkle}>
          {t("yonKararKaydet")}
        </Dugme>
      </Kart>

      {/* ----------------------------- dokumanlar -------------------------- */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("yonDokumanlar")}</h2>
        <HataDurumu mesaj={dErr ? t("yonDokumanHata") : null} />
        {dokumanlar && dokumanlar.items.length === 0 && !dErr ? (
          <BosDurum baslik={t("yonDokumanYok")} aciklama={t("yonDokumanYokAlt")} />
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
                      <Dugme tur="tehlike" boy="kucuk" onClick={() => dokumanSil(d.id)}>
                        {t("ortakSil")}
                      </Dugme>
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
      </Kart>

      {/* ------------------------- KVKK aydinlatma ------------------------- */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("yonKvkk")}</h2>
        <HataDurumu mesaj={kvErr ? t("yonKvkkHata") : null} />
        {kvkk && kvkk.length === 0 && !kvErr ? (
          <BosDurum baslik={t("yonKvkkYok")} aciklama={t("yonKvkkYokAlt")} />
        ) : null}
        {kvkk && kvkk.length > 0 ? (
          <ul className="mb-3 space-y-1 text-sm">
            {kvkk.map((m) => (
              <li key={m.id} className="flex justify-between gap-3">
                <span>
                  v{m.surum} · {m.baslik}
                </span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{formatDateTime(m.created_at)}</span>
              </li>
            ))}
          </ul>
        ) : null}
        <p className="mb-2 text-xs text-metin-muted">{t("yonKvkkNotu")}</p>
        <AlanSarmal etiket={t("yonKvkkBaslik")}>
  {(b) => (
    <Alan {...b} value={kvBaslik} onChange={(e) => setKvBaslik(e.target.value)} />
  )}
</AlanSarmal>
        <AlanSarmal etiket={t("yonKvkkGovde")}>
            {(b) => (
              <CokSatir {...b} rows={4} value={kvGovde}
            onChange={(e) => setKvGovde(e.target.value)} />
            )}
          </AlanSarmal>
        <Dugme tur="birincil" onClick={kvkkYayinla}>
          {t("yonKvkkYayinla")}
        </Dugme>
      </Kart>

      {/* -------------------------- gurultu uyarilari ---------------------- */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("yonUyarilar")}</h2>
        <HataDurumu mesaj={uErr ? t("yonUyariHata") : null} />
        {uyarilar && uyarilar.items.length === 0 && !uErr ? (
          <BosDurum baslik={t("yonUyariYok")} aciklama={t("yonUyariYokAlt")} />
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
                        <Dugme boy="kucuk" onClick={() => uyariYapildi(u.id)}>
                          {t("yonUyariYapildi")}
                        </Dugme>
                      ) : null}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Tablo>
          </div>
        ) : null}
      </Kart>

      {/* (P154 / Asama 8) SITE AKTARIM BURADAN CIKTI. Ice aktarim artik
          TEK CATI uzerinden yapiliyor (`/ice-aktarim`): kolon esleme,
          onizleme, hata raporu ve GERI ALMA orada. Ikinci bir yukleme
          yuzeyi tutmak, ayni akisi iki yerde surdurmek olurdu. */}
      <Kart>
        <h2 className="mb-1" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("yonAktar")}
        </h2>
        <p className="mb-3" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("yonAktarTasindi")}
        </p>
        {/* BAGLANTI, DUGME DEGIL — baska bir sayfaya goturur. */}
        <Link
          href="/ice-aktarim"
          className="odak-ic yz-lift inline-flex items-center px-3 py-2"
          style={{
            borderRadius: "var(--yz-radius-btn)",
            border: "var(--yz-border-w) solid var(--yz-border)",
            fontSize: "var(--yz-fs-sm)",
            color: "var(--yz-on-fill)",
            background: "var(--yz-metal-accent)",
          }}
        >
          {t("iceAktarimBaslik")}
        </Link>
      </Kart>
    </div>
  );
}
