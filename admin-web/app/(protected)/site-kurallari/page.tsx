"use client";

/**
 * (P162) SITE KURALLARI — YONETIM EKRANI.
 *
 * =========================================================================
 * NEDEN AYRI SAYFA, NEDEN `/kurallar`A DUGME EKLENMEDI
 * =========================================================================
 * Olculdu (`docs/web-mobil-esitlik.md`): mobilde site kurali eklenip
 * duzenlenip silinebiliyordu, webde YALNIZ OKUNABILIYORDU. Uclar
 * (`POST/PATCH/DELETE /site-rules`) zaten vardi.
 *
 * ILK DENEMEM YANLISTI: yazma dugmelerini `/kurallar` sayfasina ekledim.
 * `tests/sakin-okuma.dom.test.ts` bunu dusurdu ve HAKLIYDI — orasi SAKIN
 * GORUNUMUDUR (P126.3). Sakine, basinca 403 alacagi bir dugme gostermek
 * "yetkim var sandim" demektir.
 *
 * Dogru desen zaten depoda vardi: `/duyurular` (sakin) ile
 * `/announcements` (yonetim) AYRI sayfalardir. Bu dosya o desenin site
 * kurallarindaki karsiligi. Rol kapisi `lib/yuzey.ts`te
 * `["admin", "yonetici"]` — sunucudaki `_MANAGER` ile AYNI kume.
 *
 * SIRA ALANI GORUNUR: kurallar numaralandirilmis bir metindir ve
 * yonetimin verdigi sira anlamlidir. Otomatik siralamak (or. olusturma
 * zamani) o anlami sessizce silerdi.
 */
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  Iskelet,
  Kart,
  Modal,
  useOnay,
} from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

interface Kural {
  id: string;
  baslik: string;
  icerik: string;
  sira: number;
}

const UC = "/api/site-rules?limit=100&offset=0";
const BOS_FORM = { baslik: "", icerik: "", sira: "" };

export default function SiteKurallariYonetimPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const { data, error, isLoading, mutate } = useSWR<{ items: Kural[] }>(UC, jsonFetcher);
  const kurallar = data?.items ?? [];

  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<Kural | null>(null);
  const [form, setForm] = useState(BOS_FORM);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function yeniAc() {
    setDuzenlenen(null);
    // SIRA ONERISI: en buyuk + 1. Varsayilan 0 birakmak, yeni kurali
    // listenin BASINA atardi — yonetim yeni kurali genelde SONA ekler.
    const enBuyuk = kurallar.reduce((n, k) => Math.max(n, k.sira), 0);
    setForm({ ...BOS_FORM, sira: String(enBuyuk + 1) });
    setFormHata(null);
    setAcik(true);
  }

  function duzenleAc(k: Kural) {
    setDuzenlenen(k);
    setForm({ baslik: k.baslik, icerik: k.icerik, sira: String(k.sira) });
    setFormHata(null);
    setAcik(true);
  }

  async function kaydet(e: React.FormEvent) {
    e.preventDefault();
    setMesgul(true);
    setFormHata(null);
    try {
      const sira = Number(form.sira);
      const govde = {
        baslik: form.baslik,
        icerik: form.icerik,
        sira: Number.isFinite(sira) && sira >= 0 ? sira : 0,
      };
      if (duzenlenen) await apiSend(`/api/site-rules/${duzenlenen.id}`, "PATCH", govde);
      else await apiSend("/api/site-rules", "POST", govde);
      setAcik(false);
      mutate();
      toast.success(t("ortakKaydedildi"));
    } catch (err) {
      // Alan ayrintisi varsa gosterilir (P162 §4.1 ile ayni yardimci).
      setFormHata(alanliHataMetni(err, t("ortakKaydedilemedi")));
    } finally {
      setMesgul(false);
    }
  }

  async function sil(k: Kural) {
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("ortakSilOnay", { ad: k.baslik }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(`/api/site-rules/${k.id}`, "DELETE");
      mutate();
      toast.success(t("ortakSilindi"));
    } catch (err) {
      toast.error(alanliHataMetni(err, t("ortakSilinemedi")));
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kuralYonetimBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kuralYonetimAlt")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={yeniAc}>
          {t("kuralYeni")}
        </Dugme>
      </div>

      <Modal
        acik={acik}
        onKapat={() => setAcik(false)}
        baslik={duzenlenen ? t("kuralDuzenle") : t("kuralYeni")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAcik(false)} disabled={mesgul}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="kural-form" yukleniyor={mesgul}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="kural-form" onSubmit={kaydet} className="space-y-4">
          <AlanSarmal etiket={t("ortakBaslik")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.baslik}
                onChange={(e) => setForm({ ...form, baslik: e.target.value })}
                maxLength={200}
                required
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("kuralIcerik")} zorunlu>
            {(b) => (
              <CokSatir
                {...b}
                rows={8}
                value={form.icerik}
                onChange={(e) => setForm({ ...form, icerik: e.target.value })}
                maxLength={10000}
                required
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("ortakSira")} ipucu={t("kuralSiraIpucu")}>
            {(b) => (
              <Alan
                {...b}
                inputMode="numeric"
                value={form.sira}
                onChange={(e) => setForm({ ...form, sira: e.target.value })}
              />
            )}
          </AlanSarmal>
          <HataDurumu mesaj={formHata} />
        </form>
      </Modal>

      {/* HATA VARKEN "kayit yok" DENMEZ (P61): liste `?? []`den turer ve
          istek dustugunde de bos gorunurdu — "kural yok" bir IDDIADIR. */}
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => mutate()} /> : null}
      {isLoading && !data ? <Iskelet className="h-24 w-full" /> : null}
      {!isLoading && !error && kurallar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("kuralYonetimBos")} />
        </Kart>
      ) : null}

      <ol className="space-y-3">
        {kurallar.map((k) => (
          <li key={k.id}>
            <Kart className="space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                    {k.baslik}
                  </h2>
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {t("kuralSiraEtiketi", { sira: k.sira })}
                  </p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <Dugme boy="kucuk" onClick={() => duzenleAc(k)}>
                    {t("ortakDuzenle")}
                  </Dugme>
                  <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(k)}>
                    {t("ortakSil")}
                  </Dugme>
                </div>
              </div>
              <p
                className="whitespace-pre-line"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
              >
                {k.icerik}
              </p>
            </Kart>
          </li>
        ))}
      </ol>
      {diyalog}
    </div>
  );
}
