"use client";

import { useMemo, useState } from "react";
import useSWR, { mutate } from "swr";

import { Foto } from "@/components/Foto";
import { Pager } from "@/components/form";
import {
  Alan,
  CokSatir,
  Dugme,
  Kart,
  Rozet,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
  AlanSarmal,
  HataDurumu,
  IskeletMetin,
  Secim,
} from "@/components/ui";
import { agIstegi, sunucuMesaji } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

const R_OLUMLU = "olumlu" as const;
const R_UYARI = "uyari" as const;
const LIMIT = 50;

type SupportTicket = {
  id: string;
  tenant_id: string;
  tenant_ad: string | null;
  acan_user_id: string;
  konu: string;
  aciklama: string;
  durum: "acik" | "cozuldu";
  admin_cevap: string | null;
  foto_url: string | null;
  admin_cevap_foto_url: string | null;
  created_at: string;
};

type SupportList = {
  meta: { limit: number; offset: number; total: number };
  items: SupportTicket[];
};

// Destek kanali (WP1): tum tesislerin yonetici biletleri — filtre (durum +
// tenant), detayda yanit + cozuldu isareti. Backend RBAC admin'i zorlar.
export default function SupportPage() {
  const t = useT();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const [durum, setDurum] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [secili, setSecili] = useState<SupportTicket | null>(null);
  const [cevap, setCevap] = useState("");
  const [dosya, setDosya] = useState<File | null>(null);
  const [cozulduIsaretle, setCozulduIsaretle] = useState(true);
  const [gonderiliyor, setGonderiliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  const qs = new URLSearchParams({ limit: String(tabloDurumu.boy), offset: String(offset) });
  if (durum) qs.set("durum", durum);
  if (tenantId) qs.set("tenant_id", tenantId);
  const url = `/api/support?${qs.toString()}`;
  const { data, error, isLoading } = useSWR<SupportList>(url, jsonFetcher);

  async function yanitla() {
    if (!secili) return;
    setGonderiliyor(true);
    setHata(null);
    try {
      // Yanit gorseli varsa once BFF upload proxy'sinden foto_key al.
      let adminCevapFotoKey: string | undefined;
      if (dosya) {
        const fd = new FormData();
        fd.append("file", dosya);
        // (P102) `agIstegi`: ag hatasi CEVRILIR, 401 islenir (null doner).
        const up = await agIstegi("/api/uploads", { method: "POST", body: fd });
        if (up === null) return;
        // (P103) SUNUCUNUN MESAJI ONCE. Backend hata zarfinda
        // (`{error:{code,message}}`) KULLANICI DILINDE ve SEBEBE OZEL bir
        // metin doner ("Dosya cok buyuk", "Desteklenmeyen bicim"...).
        // Burasi onu ATIP yerine "Gorsel yuklenemedi (413)" gibi bir KOD
        // gosteriyordu: kullanici NEDEN olmadigini ogrenemiyordu. Zarf
        // yoksa (vekil/ag katmani) genel metne dusulur.
        if (!up.ok) throw new Error(await sunucuMesaji(up, t("destekGorselYuklenemediKod", { kod: up.status })));
        adminCevapFotoKey = ((await up.json()) as { foto_key: string }).foto_key;
      }
      const res = await agIstegi(`/api/support/${secili.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...(cevap.trim() ? { admin_cevap: cevap.trim() } : {}),
          ...(cozulduIsaretle ? { durum: "cozuldu" } : {}),
          ...(adminCevapFotoKey
            ? { admin_cevap_foto_key: adminCevapFotoKey }
            : {}),
        }),
      });
      if (res === null) return;
      if (!res.ok) throw new Error(await sunucuMesaji(res, t("destekYanitKaydedilemedi", { kod: res.status })));
      setSecili(null);
      setCevap("");
      setDosya(null);
      await mutate(url);
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setGonderiliyor(false);
    }
  }

  const kolonlar: Kolon<SupportTicket>[] = useMemo(
    () => [
      {
        id: "tarih",
        baslik: t("ortakTarih"),
        gizlenebilir: false,
        hucre: (b) => <span className="whitespace-nowrap">{formatDateTime(b.created_at)}</span>,
      },
      {
        id: "tesis",
        baslik: t("ortakTesis"),
        hucre: (b) => b.tenant_ad ?? b.tenant_id.slice(0, 8),
      },
      {
        id: "konu",
        baslik: t("destekKonu"),
        hucre: (b) => (
          <div className="max-w-[28rem]">
            <div className="flex items-center gap-1" style={{ fontWeight: 600 }}>
              {b.konu}
              {b.foto_url ? (
                <span title={t("destekGorselEkli")} aria-label={t("destekGorselEkli")}>
                  📷
                </span>
              ) : null}
            </div>
            <div
              className="truncate"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {b.aciklama}
            </div>
          </div>
        ),
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (b) => (
          <Rozet durum={b.durum === "cozuldu" ? R_OLUMLU : R_UYARI}>
            {b.durum === "cozuldu" ? t("destekCozuldu") : t("ortakAcik")}
          </Rozet>
        ),
      },
      {
        id: "yanit",
        baslik: t("destekYanit"),
        darEkrandaGizle: true,
        hucre: (b) => (
          <span
            className="block max-w-[16rem] truncate"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
          >
            {b.admin_cevap ?? "—"}
          </span>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (b) => (
          <Dugme
            boy="kucuk"
            onClick={() => {
              setSecili(b);
              setCevap(b.admin_cevap ?? "");
              setCozulduIsaretle(b.durum !== "cozuldu");
            }}
          >
            {t("destekYanitla")}
          </Dugme>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukDestek")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("destekAciklama")}
        </p>
      </div>

      <div className="flex flex-wrap gap-3">
        <AlanSarmal etiket={t("ortakDurum")}>
  {(b) => (
    <Secim {...b} value={durum}
            onChange={(e) => {
              setDurum(e.target.value);
              setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
            }}
          >
            <option value="">{t("ortakTumu")}</option>
            <option value="acik">{t("ortakAcik")}</option>
            <option value="cozuldu">{t("destekCozuldu")}</option></Secim>
  )}
</AlanSarmal>
        <AlanSarmal etiket={t("destekTesisTenantId")}>
  {(b) => (
    <Alan {...b} value={tenantId}
            placeholder={t("destekUuidBos")}
            onChange={(e) => {
              setTenantId(e.target.value.trim());
              setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
            }} />
  )}
</AlanSarmal>
      </div>

      {/* (P60) `String(error)` DEGIL `error.message`: `String(hata)` bir
          `Error` nesnesinde **"Error: "** onekini de yazar ve kullanici
          "Error: Baglanti yok." gorurdu — `jsonFetcher`in ozenle cevirdigi
          metin, tek bir cagri yerinde teknik bir onekle bozuluyordu. */}
      {/* LISTE HATASI TABLONUN ICINDE (`hata` ozelligi). Burada ikinci
          bir kutu daha cizmek AYNI mesaji iki kez gostermek olurdu.
          Buradaki kutu YANITLAMA eyleminin hatasidir — ayri bir sey. */}
      <HataDurumu mesaj={hata} />

      <VeriTablosu<SupportTicket>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(b) => b.id}
        /* (P60) HATA VARKEN "TALEP YOK" YAZILMAZ: eski kosul `!data || ...`
           idi ve istek dustugunde sayfa "Destek talebi yok" derdi — hemen
           ustundeki hata kutusuyla CELISEREK. Karar artik tablonun icinde. */
        hata={error instanceof Error ? error.message : null}
        onTekrar={() => void mutate(url)}
        yukleniyor={isLoading && !data}
        bosBaslik={t("destekTalepYok")}
        bosAciklama={t("destekBiletYok")}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />

      {secili ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-lg rounded-kart bg-white p-5 shadow-xl dark:bg-slate-900">
            <h2 className="text-base font-semibold">{secili.konu}</h2>
            <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {secili.tenant_ad ?? secili.tenant_id} · {formatDateTime(secili.created_at)}
            </p>
            <p className="mt-3 whitespace-pre-wrap rounded-lg bg-yuzey-bg p-3 text-sm dark:bg-slate-800">
              {secili.aciklama}
            </p>
            {secili.foto_url ? (
              <Foto
                src={secili.foto_url}
                alt={t("destekTalepGorseli")}
                className="mt-3 h-48 w-full rounded-lg border kart-kenar object-contain dark:border-slate-700"
              />
            ) : null}
            <AlanSarmal etiket={t("destekYanit")}>
              {(b) => (
                <CokSatir
                  {...b}
                  rows={4}
                  value={cevap}
                  onChange={(e) => setCevap(e.target.value)}
                  maxLength={4000}
                />
              )}
            </AlanSarmal>
            {secili.admin_cevap_foto_url ? (
              <div className="mb-2">
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("destekMevcutYanitGorseli")}</p>
                <Foto
                  src={secili.admin_cevap_foto_url}
                  alt={t("destekYanitGorseli")}
                  className="mt-1 h-40 w-full rounded-lg border kart-kenar object-contain dark:border-slate-700"
                />
              </div>
            ) : null}
            <AlanSarmal etiket={t("destekYanitGorseliOpsiyonel")}>
  {(b) => (
    <Alan {...b} type="file"
                accept="image/*"onChange={(e) => setDosya(e.target.files?.[0] ?? null)} />
  )}
</AlanSarmal>
            <label className="mt-2 flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={cozulduIsaretle}
                onChange={(e) => setCozulduIsaretle(e.target.checked)}
              />
              {t("destekCozulduIsaretle")}
            </label>
            <div className="mt-4 flex justify-end gap-2">
              <button
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-600"
                onClick={() => {
                  setSecili(null);
                  setDosya(null);
                }}
                disabled={gonderiliyor}
              >
                {t("ortakVazgec")}
              </button>
              <button
                className="rounded-lg bg-slate-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900"
                onClick={yanitla}
                disabled={
                  gonderiliyor || (!cevap.trim() && !cozulduIsaretle && !dosya)
                }
              >
                {gonderiliyor ? t("destekGonderiliyor") : t("destekGonder")}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
