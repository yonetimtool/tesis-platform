"use client";

import { useState } from "react";
import useSWR, { mutate } from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Foto } from "@/components/Foto";
import { ErrorBox, Field, PageHeader, Pager, inputCls } from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { agIstegi, sunucuMesaji } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

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
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [secili, setSecili] = useState<SupportTicket | null>(null);
  const [cevap, setCevap] = useState("");
  const [dosya, setDosya] = useState<File | null>(null);
  const [cozulduIsaretle, setCozulduIsaretle] = useState(true);
  const [gonderiliyor, setGonderiliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
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

  return (
    <div className="space-y-4">
      <PageHeader
        title={t("kabukDestek")}
        subtitle={t("destekAciklama")}
      />

      <div className="flex flex-wrap gap-3">
        <Field label={t("ortakDurum")}>
          <select
            className={inputCls}
            value={durum}
            onChange={(e) => {
              setDurum(e.target.value);
              setOffset(0);
            }}
          >
            <option value="">{t("ortakTumu")}</option>
            <option value="acik">{t("ortakAcik")}</option>
            <option value="cozuldu">{t("destekCozuldu")}</option>
          </select>
        </Field>
        <Field label={t("destekTesisTenantId")}>
          <input
            className={inputCls}
            value={tenantId}
            placeholder={t("destekUuidBos")}
            onChange={(e) => {
              setTenantId(e.target.value.trim());
              setOffset(0);
            }}
          />
        </Field>
      </div>

      {/* (P60) `String(error)` DEGIL `error.message`: `String(hata)` bir
          `Error` nesnesinde **"Error: "** onekini de yazar ve kullanici
          "Error: Baglanti yok." gorurdu — `jsonFetcher`in ozenle cevirdigi
          metin, tek bir cagri yerinde teknik bir onekle bozuluyordu. */}
      <ErrorBox message={error instanceof Error ? error.message : null} />
      <ErrorBox message={hata} />

      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : /* (P60) HATA VARKEN "TALEP YOK" YAZILMAZ. Eski kosul `!data ||
             ...` idi: istek dustugunde `data` tanimsiz olur ve sayfa
             **"Destek talebi yok"** derdi — hemen ustundeki hata kutusuyla
             CELISEREK. "Yuklenemedi" ile "hic yok" ayri seylerdir ve
             ikincisi bir iddiadir. */
        error ? null : !data || data.items.length === 0 ? (
        <EmptyState
          title={t("destekTalepYok")}
          description={t("destekBiletYok")}
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border kart-kenar dark:border-slate-700" tabIndex={0}>
          <Tablo>
            <TabloBasligi zeminsiz className="border-b kart-kenar text-xs uppercase tracking-wide dark:border-slate-700">
                <Th sik>{t("ortakTarih")}</Th>
                <Th sik>{t("ortakTesis")}</Th>
                <Th sik>{t("destekKonu")}</Th>
                <Th sik>{t("ortakDurum")}</Th>
                <Th sik>{t("destekYanit")}</Th>
                <Th sik />
              </TabloBasligi>
            <tbody>
              {data.items.map((bilet) => (
                <tr
                  key={bilet.id}
                  className="border-b border-yuzey-divider last:border-0 dark:border-slate-800"
                >
                  <Td sik className="whitespace-nowrap text-metin-muted">
                    {formatDateTime(bilet.created_at)}
                  </Td>
                  <Td sik>{bilet.tenant_ad ?? bilet.tenant_id.slice(0, 8)}</Td>
                  <Td sik className="max-w-[28rem]">
                    <div className="flex items-center gap-1 font-medium">
                      {bilet.konu}
                      {bilet.foto_url ? (
                        <span title={t("destekGorselEkli")} aria-label={t("destekGorselEkli")}>
                          📷
                        </span>
                      ) : null}
                    </div>
                    <div className="truncate text-xs text-metin-muted">{bilet.aciklama}</div>
                  </Td>
                  <Td sik>
                    <span
                      className={
                        bilet.durum === "cozuldu"
                          ? "rounded-md bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300"
                          : "rounded-md bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"
                      }
                    >
                      {bilet.durum === "cozuldu" ? t("destekCozuldu") : t("ortakAcik")}
                    </span>
                  </Td>
                  <Td sik className="max-w-[16rem] truncate text-xs text-metin-muted">
                    {bilet.admin_cevap ?? "—"}
                  </Td>
                  <Td sik hizala="end">
                    <button
                      className="odak-ic rounded-lg border border-slate-300 px-2 py-1 text-xs font-medium hover:bg-yuzey-bg dark:border-slate-600 dark:hover:bg-slate-800"
                      onClick={() => {
                        setSecili(bilet);
                        setCevap(bilet.admin_cevap ?? "");
                        setCozulduIsaretle(bilet.durum !== "cozuldu");
                      }}
                    >
                      {t("destekYanitla")}
                    </button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Tablo>
        </div>
      )}

      {data ? (
        <Pager
          limit={LIMIT}
          offset={offset}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      ) : null}

      {secili ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-lg rounded-kart bg-white p-5 shadow-xl dark:bg-slate-900">
            <h2 className="text-base font-semibold">{secili.konu}</h2>
            <p className="mt-1 text-xs text-metin-muted">
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
            <Field label={t("destekYanit")}>
              <textarea
                className={`${inputCls} min-h-[6rem]`}
                value={cevap}
                onChange={(e) => setCevap(e.target.value)}
                maxLength={4000}
              />
            </Field>
            {secili.admin_cevap_foto_url ? (
              <div className="mb-2">
                <p className="text-xs text-metin-muted">{t("destekMevcutYanitGorseli")}</p>
                <Foto
                  src={secili.admin_cevap_foto_url}
                  alt={t("destekYanitGorseli")}
                  className="mt-1 h-40 w-full rounded-lg border kart-kenar object-contain dark:border-slate-700"
                />
              </div>
            ) : null}
            <Field label={t("destekYanitGorseliOpsiyonel")}>
              <input
                type="file"
                accept="image/*"
                className={inputCls}
                onChange={(e) => setDosya(e.target.files?.[0] ?? null)}
              />
            </Field>
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
